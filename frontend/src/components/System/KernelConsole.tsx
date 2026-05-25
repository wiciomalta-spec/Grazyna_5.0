import React from 'react';
import styled from 'styled-components';
import { RuntimeSignal } from '../../core/RuntimeKernel';
import { CapabilityItem } from '../../core/CapabilityRegistry';

interface KernelConsoleProps {
  signal: RuntimeSignal;
  capabilities: CapabilityItem[];
  backendMode?: string;
}

const KernelConsole: React.FC<KernelConsoleProps> = ({ signal, capabilities, backendMode }) => {
  return (
    <Wrap>
      <Header>
        <Title>⚙️ Kernel Console</Title>
        <Badge>{backendMode || signal.recommendedMode}</Badge>
      </Header>
      <Grid>
        <Metric>
          <Label>Środowisko</Label>
          <Value>{signal.environment}</Value>
        </Metric>
        <Metric>
          <Label>Online</Label>
          <Value>{signal.online ? 'TAK' : 'NIE'}</Value>
        </Metric>
        <Metric>
          <Label>Rdzenie</Label>
          <Value>{signal.cores}</Value>
        </Metric>
        <Metric>
          <Label>Pamięć est.</Label>
          <Value>{signal.memoryEstimateGB} GB</Value>
        </Metric>
      </Grid>
      <Capabilities>
        {capabilities.map((cap) => (
          <Capability key={cap.id} $enabled={cap.enabled}>
            <strong>{cap.id}</strong>
            <span>{cap.description}</span>
          </Capability>
        ))}
      </Capabilities>
    </Wrap>
  );
};

const Wrap = styled.section`
  background: ${({ theme }) => theme.colors.background.card};
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: 12px;
  padding: 20px;
`;
const Header = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
`;
const Title = styled.h3`
  font-size: 18px;
`;
const Badge = styled.div`
  padding: 6px 10px;
  border-radius: 999px;
  background: ${({ theme }) => `${theme.colors.primary}20`};
  color: ${({ theme }) => theme.colors.primaryLight};
  font-weight: 700;
  text-transform: uppercase;
  font-size: 12px;
`;
const Grid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 12px;
  margin-bottom: 16px;
`;
const Metric = styled.div`
  padding: 12px;
  border-radius: 10px;
  background: ${({ theme }) => theme.colors.background.secondary};
`;
const Label = styled.div`
  color: ${({ theme }) => theme.colors.text.muted};
  font-size: 12px;
  margin-bottom: 6px;
`;
const Value = styled.div`
  font-weight: 700;
`;
const Capabilities = styled.div`
  display: grid;
  gap: 10px;
`;
const Capability = styled.div<{ $enabled: boolean }>`
  display: flex;
  justify-content: space-between;
  gap: 10px;
  padding: 12px;
  border-radius: 10px;
  background: ${({ theme, $enabled }) => $enabled ? `${theme.colors.success}12` : `${theme.colors.error}12`};
  border: 1px solid ${({ theme, $enabled }) => $enabled ? `${theme.colors.success}40` : `${theme.colors.error}40`};
  span {
    color: ${({ theme }) => theme.colors.text.muted};
    font-size: 13px;
  }
`;

export default KernelConsole;
