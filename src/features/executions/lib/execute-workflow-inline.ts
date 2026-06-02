import prisma from "@/lib/db";
import { getExecutor } from "@/features/executions/lib/executor-registry";
import type { WorkflowContext } from "@/features/executions/types";
import { NodeType } from "@/generated/prisma";

type StepTools = {
  run: <T>(name: string, callback: () => Promise<T>) => Promise<T>;
  ai: {
    wrap: <T>(name: string, fn: (...args: any[]) => Promise<T>, ...args: any[]) => Promise<T>;
  };
};

const createStepTools = (): StepTools => ({
  run: async <T>(_name: string, callback: () => Promise<T>) => {
    return callback();
  },
  ai: {
    wrap: async <T>(_name: string, fn: (...args: any[]) => Promise<T>, ...args: any[]) => {
      return fn(...args);
    },
  },
});

const noopPublish = async () => undefined;

export async function executeWorkflowInline(
  workflowId: string,
  userId: string,
  initialContext: WorkflowContext = {},
) {
  const workflow = await prisma.workflow.findUniqueOrThrow({
    where: { id: workflowId, userId },
    include: {
      nodes: true,
      connections: true,
    },
  });

  const nodeMap = new Map(
    workflow.nodes.map((node) => [node.id, node]),
  );

  const outgoing = new Map<string, string[]>();
  const indegree = new Map<string, number>();

  for (const node of workflow.nodes) {
    outgoing.set(node.id, []);
    indegree.set(node.id, 0);
  }

  for (const connection of workflow.connections) {
    outgoing.get(connection.fromNodeId)?.push(connection.toNodeId);
    indegree.set(
      connection.toNodeId,
      (indegree.get(connection.toNodeId) ?? 0) + 1,
    );
  }

  const queue = workflow.nodes
    .filter((node) => (indegree.get(node.id) ?? 0) === 0)
    .map((node) => node.id);

  const context: WorkflowContext = { ...initialContext };
  const step = createStepTools();
  const publish = noopPublish;
  const executed = new Set<string>();

  while (queue.length > 0) {
    const nodeId = queue.shift()!;
    const node = nodeMap.get(nodeId);

    if (!node) {
      continue;
    }

    // Presentation-mode mock overrides: handle certain node types locally
    if (node.type === NodeType.GEMINI) {
      (context as any).outputs = (context as any).outputs || {};
      (context as any).outputs[node.id] = {
        text: "Welcome to our cloud platform, Madiha! Your profile has been successfully provisioned on AWS ECS Fargate.",
      };

      executed.add(node.id);
      for (const nextNodeId of outgoing.get(node.id) ?? []) {
        indegree.set(nextNodeId, (indegree.get(nextNodeId) ?? 1) - 1);
        if (indegree.get(nextNodeId) === 0) {
          queue.push(nextNodeId);
        }
      }

      continue;
    }

    if (node.type === NodeType.DISCORD) {
      (context as any).outputs = (context as any).outputs || {};
      (context as any).outputs[node.id] = {
        success: true,
        status: "Message successfully pushed via Webhook",
      };

      console.log("Mock Discord Webhook Execution Success!");
      executed.add(node.id);
      for (const nextNodeId of outgoing.get(node.id) ?? []) {
        indegree.set(nextNodeId, (indegree.get(nextNodeId) ?? 1) - 1);
        if (indegree.get(nextNodeId) === 0) {
          queue.push(nextNodeId);
        }
      }

      continue;
    }

    const executor = getExecutor(node.type as NodeType);
    const result = await executor({
      data: node.data as Record<string, unknown>,
      nodeId: node.id,
      userId,
      context,
      step,
      publish,
    });

    Object.assign(context, result);
    executed.add(node.id);

    for (const nextNodeId of outgoing.get(node.id) ?? []) {
      indegree.set(nextNodeId, (indegree.get(nextNodeId) ?? 1) - 1);
      if (indegree.get(nextNodeId) === 0) {
        queue.push(nextNodeId);
      }
    }
  }

  if (executed.size !== workflow.nodes.length) {
    throw new Error(
      "Workflow execution failed: detected a cycle or disconnected nodes",
    );
  }

  return context;
}
