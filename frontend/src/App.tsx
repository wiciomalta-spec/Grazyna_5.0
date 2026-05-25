import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ThemeProvider } from 'styled-components';
import MainLayout from './components/Layout/MainLayout';
import Dashboard from './pages/Dashboard';
import KernelPage from './pages/Kernel';
import LoginPage from './pages/Login';
import GlobalStyles from './styles/GlobalStyles';
import { theme } from './styles/theme';

const App: React.FC = () => {
  return (
    <ThemeProvider theme={theme}>
      <GlobalStyles />
      <Router>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/" element={
            <MainLayout currentPage="dashboard">
              <Dashboard />
            </MainLayout>
          } />
          <Route path="/dashboard" element={
            <MainLayout currentPage="dashboard">
              <Dashboard />
            </MainLayout>
          } />
          <Route path="/fleet" element={
            <MainLayout currentPage="fleet">
              <div>
                <h1>Flota Pojazdów</h1>
                <p>Strona w budowie...</p>
              </div>
            </MainLayout>
          } />
          <Route path="/maps" element={
            <MainLayout currentPage="maps">
              <div>
                <h1>Mapy i Nawigacja</h1>
                <p>Strona w budowie...</p>
              </div>
            </MainLayout>
          } />
          <Route path="/analytics" element={
            <MainLayout currentPage="analytics">
              <div>
                <h1>Analityka</h1>
                <p>Strona w budowie...</p>
              </div>
            </MainLayout>
          } />
          <Route path="/kernel" element={
            <MainLayout currentPage="kernel">
              <KernelPage />
            </MainLayout>
          } />
        </Routes>
      </Router>
    </ThemeProvider>
  );
};

export default App;
