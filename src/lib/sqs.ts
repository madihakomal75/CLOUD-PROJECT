import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

const sqsClient = new SQSClient({ region: process.env.AWS_REGION });

export const sendToQueue = async (data: any) => {
  const command = new SendMessageCommand({
    QueueUrl: process.env.SQS_QUEUE_URL,
    MessageBody: JSON.stringify(data),
  });

  try {
    const result = await sqsClient.send(command);
    return result;
  } catch (error) {
    console.error("SQS Error:", error);
    throw error;
  }
};