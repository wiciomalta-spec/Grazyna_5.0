/**
 * GRAŻYNA 5.0 - Seed danych testowych
 * Wypełnia bazę danych przykładowymi danymi do developmentu
 */

import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Rozpoczynam seedowanie bazy danych...');

  // ═══════════════════════════════════════════
  // 1. Użytkownicy
  // ═══════════════════════════════════════════
  console.log('👤 Tworzę użytkowników...');
  
  const adminPassword = await bcrypt.hash('admin123', 10);
  const operatorPassword = await bcrypt.hash('operator123', 10);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@grazyna.local' },
    update: {},
    create: {
      email: 'admin@grazyna.local',
      username: 'admin',
      password: adminPassword,
      firstName: 'Administrator',
      lastName: 'Systemu',
      role: 'ADMIN',
    }
  });

  const operator = await prisma.user.upsert({
    where: { email: 'operator@grazyna.local' },
    update: {},
    create: {
      email: 'operator@grazyna.local',
      username: 'operator',
      password: operatorPassword,
      firstName: 'Jan',
      lastName: 'Operator',
      role: 'OPERATOR',
    }
  });

  console.log(`✓ Utworzono użytkowników: ${admin.username}, ${operator.username}`);

  // ═══════════════════════════════════════════
  // 2. Flota pojazdów
  // ═══════════════════════════════════════════
  console.log('🚗 Tworzę pojazdy...');
  
  const vehicles = [
    {
      name: 'Pojazd Alpha',
      vin: 'GRZ001ALPHA2026',
      type: 'STANDARD' as const,
      status: 'ACTIVE' as const,
      battery: 87,
      latitude: 52.2297,
      longitude: 21.0122,
      maxSpeed: 80,
      maxRange: 500
    },
    {
      name: 'Pojazd Beta',
      vin: 'GRZ002BETA2026',
      type: 'HEAVY' as const,
      status: 'ACTIVE' as const,
      battery: 92,
      latitude: 52.2387,
      longitude: 21.0217,
      maxSpeed: 60,
      maxRange: 800
    },
    {
      name: 'Pojazd Gamma',
      vin: 'GRZ003GAMMA2026',
      type: 'LIGHT' as const,
      status: 'CHARGING' as const,
      battery: 45,
      latitude: 52.2197,
      longitude: 21.0322,
      maxSpeed: 100,
      maxRange: 300
    },
    {
      name: 'Dron Delta',
      vin: 'GRZ004DELTA2026',
      type: 'DRONE' as const,
      status: 'IDLE' as const,
      battery: 100,
      latitude: 52.2497,
      longitude: 21.0422,
      maxSpeed: 120,
      maxRange: 50
    },
    {
      name: 'Pojazd Echo',
      vin: 'GRZ005ECHO2026',
      type: 'SPECIAL' as const,
      status: 'MAINTENANCE' as const,
      battery: 0,
      latitude: 52.2097,
      longitude: 21.0022,
      maxSpeed: 70,
      maxRange: 600
    }
  ];

  for (const vehicleData of vehicles) {
    await prisma.vehicle.upsert({
      where: { vin: vehicleData.vin },
      update: {},
      create: vehicleData
    });
  }

  console.log(`✓ Utworzono ${vehicles.length} pojazdów`);

  // ═══════════════════════════════════════════
  // 3. Misje
  // ═══════════════════════════════════════════
  console.log('🎯 Tworzę misje...');

  const alphaVehicle = await prisma.vehicle.findFirst({ where: { name: 'Pojazd Alpha' } });
  const betaVehicle = await prisma.vehicle.findFirst({ where: { name: 'Pojazd Beta' } });

  if (alphaVehicle && betaVehicle) {
    await prisma.mission.create({
      data: {
        name: 'Dostawa Centrum → Mokotów',
        description: 'Transport paczek do magazynu na Mokotowie',
        status: 'IN_PROGRESS',
        priority: 'HIGH',
        startedAt: new Date(),
        startLat: 52.2297,
        startLng: 21.0122,
        endLat: 52.1797,
        endLng: 21.0322,
        distance: 8.5,
        vehicleId: alphaVehicle.id,
        assignedToId: operator.id,
        waypoints: [
          { lat: 52.2297, lng: 21.0122, type: 'start' },
          { lat: 52.2097, lng: 21.0222, type: 'waypoint' },
          { lat: 52.1797, lng: 21.0322, type: 'end' }
        ]
      }
    });

    await prisma.mission.create({
      data: {
        name: 'Patrol obszaru A',
        description: 'Rutynowy patrol strefy A',
        status: 'SCHEDULED',
        priority: 'NORMAL',
        scheduledAt: new Date(Date.now() + 3600000), // za godzinę
        startLat: 52.2387,
        startLng: 21.0217,
        endLat: 52.2387,
        endLng: 21.0217,
        distance: 12.0,
        vehicleId: betaVehicle.id,
        assignedToId: operator.id,
      }
    });

    console.log('✓ Utworzono 2 misje');
  }

  // ═══════════════════════════════════════════
  // 4. Zdarzenia
  // ═══════════════════════════════════════════
  console.log('📋 Tworzę zdarzenia...');

  const events = [
    {
      type: 'SYSTEM' as const,
      severity: 'INFO' as const,
      title: 'System uruchomiony',
      message: 'GRAŻYNA 5.0 została pomyślnie zainicjalizowana',
    },
    {
      type: 'VEHICLE' as const,
      severity: 'INFO' as const,
      title: 'Pojazd Alpha rozpoczął misję',
      message: 'Dostawa do Mokotowa rozpoczęta',
      vehicleId: alphaVehicle?.id,
    },
    {
      type: 'VEHICLE' as const,
      severity: 'WARNING' as const,
      title: 'Niska bateria - Pojazd Gamma',
      message: 'Bateria spadła poniżej 50%',
      vehicleId: (await prisma.vehicle.findFirst({ where: { name: 'Pojazd Gamma' } }))?.id,
    },
    {
      type: 'MAINTENANCE' as const,
      severity: 'WARNING' as const,
      title: 'Wymagana konserwacja',
      message: 'Pojazd Echo wymaga przeglądu technicznego',
    },
  ];

  for (const eventData of events) {
    await prisma.event.create({ data: eventData });
  }

  console.log(`✓ Utworzono ${events.length} zdarzeń`);

  console.log('\n✅ Seedowanie zakończone pomyślnie!\n');
  console.log('📝 Dane logowania:');
  console.log('   Admin:    admin@grazyna.local / admin123');
  console.log('   Operator: operator@grazyna.local / operator123\n');
}

main()
  .catch((e) => {
    console.error('❌ Błąd podczas seedowania:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
