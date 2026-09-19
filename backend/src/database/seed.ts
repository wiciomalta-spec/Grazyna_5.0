/**
 * Development seed. Credentials are supplied only through environment variables.
 * Never commit real credentials.
 */
import { PrismaClient, Role, VehicleStatus, VehicleType } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required seed variable: ${name}`);
  return value;
}

async function main() {
  const adminEmail = required("SEED_ADMIN_EMAIL");
  const adminPassword = required("SEED_ADMIN_PASSWORD");
  const operatorEmail = required("SEED_OPERATOR_EMAIL");
  const operatorPassword = required("SEED_OPERATOR_PASSWORD");

  const admin = await prisma.user.upsert({
    where: { email: adminEmail },
    update: {},
    create: {
      email: adminEmail,
      username: "admin",
      passwordHash: await bcrypt.hash(adminPassword, 12),
      role: Role.ADMIN
    }
  });

  const operator = await prisma.user.upsert({
    where: { email: operatorEmail },
    update: {},
    create: {
      email: operatorEmail,
      username: "operator",
      passwordHash: await bcrypt.hash(operatorPassword, 12),
      role: Role.OPERATOR
    }
  });

  const vehicle = await prisma.vehicle.upsert({
    where: { licensePlate: "GRZ-001" },
    update: {},
    create: {
      name: "Pojazd Alpha",
      licensePlate: "GRZ-001",
      vin: "GRZ001ALPHA2026",
      type: VehicleType.STANDARD,
      status: VehicleStatus.ACTIVE,
      battery: 87,
      lat: 52.2297,
      lng: 21.0122
    }
  });

  await prisma.mission.create({
    data: {
      name: "Demo mission",
      description: "Development seed mission",
      status: "PENDING",
      priority: "NORMAL",
      vehicleId: vehicle.id,
      createdById: operator.id
    }
  });

  await prisma.event.create({
    data: {
      type: "SYSTEM",
      severity: "INFO",
      message: "GRAŻYNA development seed completed",
      userId: admin.id,
      vehicleId: vehicle.id
    }
  });

  console.log("Seed completed");
}

main()
  .catch((error) => {
    console.error("Seed failed:", error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());