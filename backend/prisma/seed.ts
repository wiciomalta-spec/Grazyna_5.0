import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log("🌱 Seed start...");

  // USERS
  const admin = await prisma.user.upsert({
    where: { email: "admin@grazyna.local" },
    update: {},
    create: {
      email: "admin@grazyna.local",
      username: "admin",
      password: "admin123",
      role: "ADMIN"
    }
  });

  const operator = await prisma.user.upsert({
    where: { email: "operator@grazyna.local" },
    update: {},
    create: {
      email: "operator@grazyna.local",
      username: "operator",
      password: "operator123",
      role: "OPERATOR"
    }
  });

  // VEHICLE
  const vehicle = await prisma.vehicle.create({
    data: {
      name: "DRONE-01",
      type: "DRONE",
      status: "IDLE",
      battery: 87,
      latitude: 52.3,
      longitude: 15.5
    }
  });

  // MISSION
  await prisma.mission.create({
    data: {
      name: "Patrol 1",
      status: "PENDING",
      vehicleId: vehicle.id,
      assignedToId: operator.id
    }
  });

  console.log("✅ Seed done");
}

main()
  .catch(e => {
    console.error(e);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });