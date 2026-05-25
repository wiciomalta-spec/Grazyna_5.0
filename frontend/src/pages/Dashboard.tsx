import React from 'react';
import styled from 'styled-components';

const Dashboard: React.FC = () => {
  return (
    <DashboardContainer>
      <Header>
        <Title>🦞 Dashboard GRAŻYNA 5.0</Title>
        <Subtitle>System Autonomicznego Zarządzania Flotą</Subtitle>
      </Header>

      <StatsGrid>
        <StatCard>
          <StatIcon>🚗</StatIcon>
          <StatValue>24</StatValue>
          <StatLabel>Aktywne Pojazdy</StatLabel>
          <StatTrend $positive>+3 od wczoraj</StatTrend>
        </StatCard>

        <StatCard>
          <StatIcon>📍</StatIcon>
          <StatValue>156 km</StatValue>
          <StatLabel>Przejechane Dziś</StatLabel>
          <StatTrend $positive>+12%</StatTrend>
        </StatCard>

        <StatCard>
          <StatIcon>⚡</StatIcon>
          <StatValue>98.5%</StatValue>
          <StatLabel>Sprawność Systemu</StatLabel>
          <StatTrend $positive>Optymalna</StatTrend>
        </StatCard>

        <StatCard>
          <StatIcon>🎯</StatIcon>
          <StatValue>12</StatValue>
          <StatLabel>Aktywne Misje</StatLabel>
          <StatTrend>3 w trakcie</StatTrend>
        </StatCard>
      </StatsGrid>

      <ContentGrid>
        <Card>
          <CardHeader>
            <CardTitle>📊 Wykres Aktywności</CardTitle>
          </CardHeader>
          <CardContent>
            <Placeholder>Wykres będzie tutaj...</Placeholder>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>🗺️ Mapa Floty</CardTitle>
          </CardHeader>
          <CardContent>
            <Placeholder>Mapa będzie tutaj...</Placeholder>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>📝 Ostatnie Zdarzenia</CardTitle>
          </CardHeader>
          <CardContent>
            <EventList>
              <Event>
                <EventIcon>✓</EventIcon>
                <EventText>Pojazd #5 ukończył trasę</EventText>
                <EventTime>2 min temu</EventTime>
              </Event>
              <Event>
                <EventIcon>🔔</EventIcon>
                <EventText>Nowa misja przypisana</EventText>
                <EventTime>5 min temu</EventTime>
              </Event>
              <Event>
                <EventIcon>⚠️</EventIcon>
                <EventText>Niska bateria - Pojazd #3</EventText>
                <EventTime>12 min temu</EventTime>
              </Event>
            </EventList>
          </CardContent>
        </Card>
      </ContentGrid>
    </DashboardContainer>
  );
};

const DashboardContainer = styled.div`
  padding: 24px;
  width: 100%;
  height: 100%;
  overflow-y: auto;
`;

const Header = styled.div`
  margin-bottom: 32px;
`;

const Title = styled.h1`
  font-size: 32px;
  font-weight: 800;
  background: linear-gradient(45deg, #00E5FF, #7C3AED);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  margin-bottom: 8px;
`;

const Subtitle = styled.p`
  color: ${({ theme }) => theme.colors.text.muted};
  font-size: 16px;
`;

const StatsGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 32px;
`;

const StatCard = styled.div`
  background: ${({ theme }) => theme.colors.background.card};
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: 12px;
  padding: 24px;
  transition: all 0.3s ease;

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 10px 30px rgba(124, 58, 237, 0.2);
    border-color: ${({ theme }) => theme.colors.primary};
  }
`;

const StatIcon = styled.div`
  font-size: 32px;
  margin-bottom: 12px;
`;

const StatValue = styled.div`
  font-size: 36px;
  font-weight: 800;
  color: ${({ theme }) => theme.colors.text.primary};
  margin-bottom: 8px;
`;

const StatLabel = styled.div`
  font-size: 14px;
  color: ${({ theme }) => theme.colors.text.muted};
  margin-bottom: 8px;
`;

const StatTrend = styled.div<{ $positive?: boolean }>`
  font-size: 12px;
  color: ${({ theme, $positive }) => 
    $positive ? theme.colors.success : theme.colors.text.muted};
  font-weight: 600;
`;

const ContentGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 24px;
`;

const Card = styled.div`
  background: ${({ theme }) => theme.colors.background.card};
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: 12px;
  overflow: hidden;
`;

const CardHeader = styled.div`
  padding: 20px 24px;
  border-bottom: 1px solid ${({ theme }) => theme.colors.border};
`;

const CardTitle = styled.h3`
  font-size: 18px;
  font-weight: 700;
`;

const CardContent = styled.div`
  padding: 24px;
`;

const Placeholder = styled.div`
  height: 200px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: ${({ theme }) => theme.colors.background.secondary};
  border-radius: 8px;
  color: ${({ theme }) => theme.colors.text.muted};
  font-style: italic;
`;

const EventList = styled.div`
  display: flex;
  flex-direction: column;
  gap: 16px;
`;

const Event = styled.div`
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: ${({ theme }) => theme.colors.background.secondary};
  border-radius: 8px;
  transition: all 0.2s ease;

  &:hover {
    background: ${({ theme }) => theme.colors.background.hover};
  }
`;

const EventIcon = styled.div`
  font-size: 20px;
`;

const EventText = styled.div`
  flex: 1;
  font-size: 14px;
`;

const EventTime = styled.div`
  font-size: 12px;
  color: ${({ theme }) => theme.colors.text.muted};
`;

export default Dashboard;
