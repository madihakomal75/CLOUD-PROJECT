import { NextResponse } from 'next/server';
import prisma from '@/lib/db'; // Adjust this path to your Prisma client

export async function GET() {
  try {
    // 1. Check Database Connection
    await prisma.$queryRaw`SELECT 1`;

    return NextResponse.json(
      { 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        service: 'nodebase-api' 
      },
      { status: 200 }
    );
  } catch (error) {
    return NextResponse.json(
      { status: 'unhealthy', error: 'Database connection failed' },
      { status: 503 }
    );
  }
}