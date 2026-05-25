import React, { useEffect, useMemo, useState } from 'react';
import styled from 'styled-components';
import KernelConsole from '../components/System/KernelConsole';
import { runtimeKernel } from '../core/RuntimeKernel';
import { capabilityRegistry } from '../core/CapabilityRegistry';
import api from '../services/api';

const KernelPage: React.FC = () => {
  const signal = useMemo(() => runtimeKernel.profile(), []);
  const capabilities = useMemo(() => capabilityRegistry.list(), []);
  const [backendMode, setBackendMode] = useState<string>('loading');
  const [profileSummary, setProfileSummary] = useState<string>('Analiza środowiska trwa...');

  useEffect(() => {
    const load = async () => {
      try {
        const response = await api.getKernelProfile();
        const adapt = await api.adaptKernel({ mode: signal.recommendedMode });
        setBackendMode(adapt.data.mode);
        setProfileSummary(`Platforma ${response.data.platform}, ${response.data.cpuCount} CPU, ${response.data.totalMemoryMB} MB RAM, tryb ${adapt.data.mode}.`);
      } catch {
        setBackendMode(signal.recommendedMode);
        setProfileSummary('Backend kernel niedostępny — aktywny tryb lokalny i portable fallback.');
      }
    };
    load();
  }, [signal.recommendedMode]);

  return (
    <Wrap>
      <Hero>
        <h1>🧠 GRAŻYNA Hybrid Kernel</h1>
        <p>Warstwa autonomii, która profiluje środowisko, dobiera tryb pracy i utrzymuje lekki rdzeń niezależny od platformy.</p>
      </Hero>

      <KernelConsole signal={signal} capabilities={capabilities} backendMode={backendMode} />

      <Summary>{profileSummary}</Summary>

      <Section>
        <Card>
          <h3>Tryby pracy</h3>
          <ul>
            <li>minimal — najmniejszy narzut i ograniczenie animacji</li>
            <li>balanced — równowaga UX i wydajności</li>
            <li>turbo — maksymalna telemetria i agresywny cache</li>
            <li>portable — działanie awaryjne i offline-first</li>
            <li>autonomous — samodzielne przełączanie strategii</li>
          </ul>
        </Card>
        <Card>
          <h3>Zdolności rdzenia</h3>
          <ul>
            <li>samodiagnoza środowiska</li>
            <li>hybrydowa warstwa sterowników</li>
            <li>odporność na utratę połączenia</li>
            <li>lokalne odzyskiwanie stanu</li>
            <li>adaptacja do słabych i mocnych maszyn</li>
          </ul>
        </Card>
      </Section>
    </Wrap>
  );
};

const Wrap = styled.div`
  padding: 24px;
  display: grid;
  gap: 20px;
`;
const Hero = styled.section`
  background: linear-gradient(135deg, rgba(124,58,237,0.24), rgba(0,229,255,0.12));
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: 16px;
  padding: 24px;
  h1 { margin-bottom: 10px; }
  p { color: ${({ theme }) => theme.colors.text.secondary}; max-width: 900px; }
`;
const Summary = styled.div`
  padding: 16px 18px;
  border-radius: 12px;
  background: ${({ theme }) => theme.colors.background.card};
  border: 1px solid ${({ theme }) => theme.colors.border};
`;
const Section = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 20px;
`;
const Card = styled.div`
  background: ${({ theme }) => theme.colors.background.card};
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: 12px;
  padding: 20px;
  h3 { margin-bottom: 12px; }
  ul { padding-left: 18px; color: ${({ theme }) => theme.colors.text.secondary}; display: grid; gap: 8px; }
`;

export default KernelPage;
