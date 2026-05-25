import React, { useState } from 'react';
import styled from 'styled-components';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';

const LoginPage: React.FC = () => {
  const navigate = useNavigate();
  const { login, isLoading, error, clearError } = useAuthStore();
  const [email, setEmail] = useState('admin@grazyna.local');
  const [password, setPassword] = useState('admin123');

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    clearError();
    try {
      await login(email, password);
      navigate('/kernel');
    } catch {
      // handled by store
    }
  };

  return (
    <Wrap>
      <Card>
        <Logo>🦞</Logo>
        <h1>Logowanie GRAŻYNA 5.0</h1>
        <p>Wejście do warstwy administracyjnej, kernel i operacji floty.</p>
        <Form onSubmit={onSubmit}>
          <Input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" />
          <Input value={password} onChange={(e) => setPassword(e.target.value)} type="password" placeholder="Hasło" />
          <Button type="submit" disabled={isLoading}>{isLoading ? 'Logowanie...' : 'Zaloguj'}</Button>
        </Form>
        {error && <ErrorBox>{error}</ErrorBox>}
        <Hint>Dane demo: admin@grazyna.local / admin123</Hint>
      </Card>
    </Wrap>
  );
};

const Wrap = styled.div`
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background: radial-gradient(circle at top, rgba(124,58,237,0.24), transparent 40%), #0f172a;
`;
const Card = styled.div`
  width: 100%;
  max-width: 440px;
  background: ${({ theme }) => theme.colors.background.card};
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: 18px;
  padding: 28px;
  display: grid;
  gap: 14px;
  p { color: ${({ theme }) => theme.colors.text.secondary}; }
`;
const Logo = styled.div`
  font-size: 48px;
`;
const Form = styled.form`
  display: grid;
  gap: 12px;
`;
const Input = styled.input`
  height: 46px;
  border-radius: 10px;
  border: 1px solid ${({ theme }) => theme.colors.border};
  background: ${({ theme }) => theme.colors.background.input};
  color: ${({ theme }) => theme.colors.text.primary};
  padding: 0 14px;
`;
const Button = styled.button`
  height: 48px;
  border: 0;
  border-radius: 10px;
  background: linear-gradient(135deg, #7c3aed, #00e5ff);
  color: white;
  font-weight: 800;
`;
const ErrorBox = styled.div`
  padding: 12px;
  border-radius: 10px;
  background: rgba(239,68,68,0.12);
  border: 1px solid rgba(239,68,68,0.4);
  color: #fecaca;
`;
const Hint = styled.div`
  color: ${({ theme }) => theme.colors.text.muted};
  font-size: 13px;
`;

export default LoginPage;
