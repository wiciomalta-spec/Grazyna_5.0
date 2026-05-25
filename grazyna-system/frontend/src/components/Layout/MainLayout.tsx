import React, { useState } from 'react';
import styled from 'styled-components';
import { motion } from 'framer-motion';

interface MainLayoutProps {
  children: React.ReactNode;
  currentPage?: string;
}

const MainLayout: React.FC<MainLayoutProps> = ({ children, currentPage = 'dashboard' }) => {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  const menuItems = [
    { id: 'dashboard', label: 'Dashboard', icon: '📊', path: '/dashboard' },
    { id: 'fleet', label: 'Flota', icon: '🚗', path: '/fleet' },
    { id: 'maps', label: 'Mapy', icon: '🗺️', path: '/maps' },
    { id: 'analytics', label: 'Analityka', icon: '📈', path: '/analytics' },
    { id: 'missions', label: 'Misje', icon: '🎯', path: '/missions' },
    { id: 'kernel', label: 'Kernel', icon: '🧠', path: '/kernel' },
    { id: 'settings', label: 'Ustawienia', icon: '⚙️', path: '/settings' },
  ];

  return (
    <LayoutContainer>
      {/* Top Bar */}
      <TopBar>
        <TopBarLeft>
          <MenuButton onClick={() => setSidebarCollapsed(!sidebarCollapsed)}>
            ☰
          </MenuButton>
          <Logo>
            <LogoIcon>🦞</LogoIcon>
            <LogoText>
              <LogoTitle>GRAŻYNA 5.0</LogoTitle>
              <LogoSubtitle>Fleet Management</LogoSubtitle>
            </LogoText>
          </Logo>
        </TopBarLeft>

        <TopBarCenter>
          <SearchBar>
            <SearchIcon>🔍</SearchIcon>
            <SearchInput placeholder="Szukaj pojazdów, map, narzędzi..." />
          </SearchBar>
        </TopBarCenter>

        <TopBarRight>
          <StatusIndicator $status="online">
            <StatusDot />
            Adaptive Core Online
          </StatusIndicator>
          <IconButton title="Powiadomienia">
            <Badge>3</Badge>
            🔔
          </IconButton>
          <IconButton title="Ustawienia">⚙️</IconButton>
          <UserAvatar>
            <UserAvatarIcon>👤</UserAvatarIcon>
          </UserAvatar>
        </TopBarRight>
      </TopBar>

      <MainContent>
        {/* Sidebar */}
        <Sidebar $collapsed={sidebarCollapsed}>
          <SidebarMenu>
            {menuItems.map((item) => (
              <MenuItem
                key={item.id}
                $active={currentPage === item.id}
                $collapsed={sidebarCollapsed}
                as={motion.a}
                href={item.path}
                whileHover={{ x: 4 }}
                whileTap={{ scale: 0.98 }}
              >
                <MenuIcon>{item.icon}</MenuIcon>
                {!sidebarCollapsed && <MenuLabel>{item.label}</MenuLabel>}
              </MenuItem>
            ))}
          </SidebarMenu>
        </Sidebar>

        {/* Content Area */}
        <ContentArea $sidebarCollapsed={sidebarCollapsed}>
          {children}
        </ContentArea>
      </MainContent>

      {/* Status Bar */}
      <StatusBar>
        <StatusItem>
          <StatusLabel>CPU:</StatusLabel>
          <StatusValue>42%</StatusValue>
        </StatusItem>
        <StatusItem>
          <StatusLabel>RAM:</StatusLabel>
          <StatusValue>67%</StatusValue>
        </StatusItem>
        <StatusItem>
          <StatusLabel>Połączenia:</StatusLabel>
          <StatusValue>24/24</StatusValue>
        </StatusItem>
        <StatusItem>
          <StatusLabel>Wersja:</StatusLabel>
          <StatusValue>5.0.0</StatusValue>
        </StatusItem>
      </StatusBar>
    </LayoutContainer>
  );
};

// Styled Components
const LayoutContainer = styled.div`
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: ${({ theme }) => theme.colors.background.primary};
  overflow: hidden;
`;

const TopBar = styled.header`
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 64px;
  padding: 0 24px;
  background: ${({ theme }) => theme.colors.background.card};
  border-bottom: 1px solid ${({ theme }) => theme.colors.border};
  z-index: 100;
`;

const TopBarLeft = styled.div`
  display: flex;
  align-items: center;
  gap: 16px;
  min-width: 280px;
`;

const TopBarCenter = styled.div`
  flex: 1;
  max-width: 600px;
  margin: 0 32px;
`;

const TopBarRight = styled.div`
  display: flex;
  align-items: center;
  gap: 16px;
`;

const MenuButton = styled.button`
  width: 40px;
  height: 40px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: 1px solid ${({ theme }) => theme.colors.border};
  color: ${({ theme }) => theme.colors.text.primary};
  font-size: 20px;
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    background: ${({ theme }) => theme.colors.background.hover};
    border-color: ${({ theme }) => theme.colors.primary};
  }
`;

const Logo = styled.div`
  display: flex;
  align-items: center;
  gap: 12px;
`;

const LogoIcon = styled.div`
  font-size: 28px;
`;

const LogoText = styled.div`
  display: flex;
  flex-direction: column;
`;

const LogoTitle = styled.h1`
  font-size: 18px;
  font-weight: 800;
  margin: 0;
  background: linear-gradient(45deg, #00E5FF, #7C3AED);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
`;

const LogoSubtitle = styled.p`
  font-size: 11px;
  color: ${({ theme }) => theme.colors.text.muted};
  margin: 0;
`;

const SearchBar = styled.div`
  position: relative;
  width: 100%;
`;

const SearchIcon = styled.div`
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  font-size: 16px;
`;

const SearchInput = styled.input`
  width: 100%;
  height: 40px;
  padding: 0 40px;
  border-radius: 20px;
  border: 1px solid ${({ theme }) => theme.colors.border};
  background: ${({ theme }) => theme.colors.background.input};
  color: ${({ theme }) => theme.colors.text.primary};
  font-size: 14px;
  transition: all 0.2s ease;

  &:focus {
    outline: none;
    border-color: ${({ theme }) => theme.colors.primary};
    box-shadow: 0 0 0 3px ${({ theme }) => theme.colors.primary}20;
  }

  &::placeholder {
    color: ${({ theme }) => theme.colors.text.muted};
  }
`;

const StatusIndicator = styled.div<{ $status: 'online' | 'offline' }>`
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  border-radius: 16px;
  background: ${({ theme, $status }) => 
    $status === 'online' 
      ? `${theme.colors.success}20` 
      : `${theme.colors.error}20`};
  color: ${({ theme, $status }) => 
    $status === 'online' ? theme.colors.success : theme.colors.error};
  font-size: 12px;
  font-weight: 600;
`;

const StatusDot = styled.div`
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
  animation: pulse 2s ease-in-out infinite;

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }
`;

const IconButton = styled.button`
  position: relative;
  width: 40px;
  height: 40px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: 1px solid ${({ theme }) => theme.colors.border};
  color: ${({ theme }) => theme.colors.text.primary};
  font-size: 18px;
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    background: ${({ theme }) => theme.colors.background.hover};
    transform: translateY(-1px);
  }
`;

const Badge = styled.span`
  position: absolute;
  top: -4px;
  right: -4px;
  width: 18px;
  height: 18px;
  background: ${({ theme }) => theme.colors.error};
  color: white;
  font-size: 10px;
  font-weight: bold;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
`;

const UserAvatar = styled.div`
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: linear-gradient(135deg, #7C3AED, #00E5FF);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    transform: scale(1.05);
  }
`;

const UserAvatarIcon = styled.div`
  font-size: 20px;
`;

const MainContent = styled.div`
  display: flex;
  flex: 1;
  overflow: hidden;
`;

const Sidebar = styled.nav<{ $collapsed: boolean }>`
  width: ${({ $collapsed }) => ($collapsed ? '80px' : '280px')};
  min-width: ${({ $collapsed }) => ($collapsed ? '80px' : '280px')};
  background: ${({ theme }) => theme.colors.background.card};
  border-right: 1px solid ${({ theme }) => theme.colors.border};
  transition: all 0.3s ease;
  overflow-y: auto;
  overflow-x: hidden;
`;

const SidebarMenu = styled.div`
  padding: 20px 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
`;

const MenuItem = styled.a<{ $active: boolean; $collapsed: boolean }>`
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-radius: 8px;
  color: ${({ theme, $active }) => 
    $active ? theme.colors.primary : theme.colors.text.secondary};
  background: ${({ theme, $active }) => 
    $active ? `${theme.colors.primary}20` : 'transparent'};
  font-weight: ${({ $active }) => ($active ? 600 : 400)};
  cursor: pointer;
  transition: all 0.2s ease;
  text-decoration: none;

  &:hover {
    background: ${({ theme, $active }) => 
      $active ? `${theme.colors.primary}30` : theme.colors.background.hover};
    color: ${({ theme }) => theme.colors.primary};
  }
`;

const MenuIcon = styled.div`
  font-size: 20px;
  min-width: 20px;
`;

const MenuLabel = styled.span`
  font-size: 14px;
  white-space: nowrap;
`;

const ContentArea = styled.main<{ $sidebarCollapsed: boolean }>`
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
`;

const StatusBar = styled.footer`
  display: flex;
  align-items: center;
  gap: 24px;
  height: 32px;
  padding: 0 24px;
  background: ${({ theme }) => theme.colors.background.card};
  border-top: 1px solid ${({ theme }) => theme.colors.border};
  font-size: 12px;
`;

const StatusItem = styled.div`
  display: flex;
  align-items: center;
  gap: 6px;
`;

const StatusLabel = styled.span`
  color: ${({ theme }) => theme.colors.text.muted};
`;

const StatusValue = styled.span`
  color: ${({ theme }) => theme.colors.text.primary};
  font-weight: 600;
`;

export default MainLayout;
