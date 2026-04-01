import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useState, useEffect } from 'react';
import Login from '@/app/components/pages/Login';
import Dashboard from '@/app/components/pages/Dashboard';
import AgentManagement from '@/app/components/pages/AgentManagement';
import AgentDetail from '@/app/components/pages/AgentDetail';
import AgentApproval from '@/app/components/pages/AgentApproval';
import AdminManagement from '@/app/components/pages/AdminManagement';
import ServiceManagement from '@/app/components/pages/ServiceManagement';
import BannerManagement from '@/app/components/pages/BannerManagement';
import AnnouncementManagement from '@/app/components/pages/AnnouncementManagement';
import ApplicationDetail from '@/app/components/pages/ApplicationDetail';
import CertificateGeneration from '@/app/components/pages/CertificateGeneration';
import WalletManagement from '@/app/components/pages/WalletManagement';
import WithdrawalManagement from '@/app/components/pages/WithdrawalManagement';
import CommissionSettings from '@/app/components/pages/CommissionSettings';
import ReferEarn from '@/app/components/pages/ReferEarn';
import TermsManagement from '@/app/components/pages/TermsManagement';
import Terms from '@/app/components/pages/Terms';
import AdminProfile from '@/app/components/pages/AdminProfile';
import RegistrationSettings from '@/app/components/pages/RegistrationSettings';
import AppointmentManagement from '@/app/components/pages/AppointmentManagement';
import SideCategoryManagement from '@/app/components/pages/SideCategoryManagement';
import MainLayout from '@/app/components/layout/MainLayout';
import RoleGuard from '@/app/components/guards/RoleGuard';
import PermissionGuard from '@/app/components/guards/PermissionGuard';
import { diagnoseFIRESTORE_DATA } from '@/utils/diagnoseFIRESTORE_DATA';
import { authService, AdminUser } from '@/services/authService';

function App() {
  const [currentUser, setCurrentUser] = useState<AdminUser | null>(null);
  const [loading, setLoading] = useState(true);

  // Listen to auth state changes
  useEffect(() => {
    const unsubscribe = authService.onAuthStateChange((user) => {
      setCurrentUser(user);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  // Expose diagnostic function to window for console access
  useEffect(() => {
    (window as any).diagnoseFIRESTORE_DATA = diagnoseFIRESTORE_DATA;
    console.log('💡 DEBUGGING TIP: Run diagnoseFIRESTORE_DATA() in console to check Firestore data');
  }, []);

  // Handle logout
  const handleLogout = async () => {
    try {
      await authService.logout();
      setCurrentUser(null);
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  // Show loading state while checking authentication
  if (loading) {
    return (
      <div className="min-h-screen bg-[#0a0f1a] flex items-center justify-center">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-[#243BFF]/30 border-t-[#243BFF] rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-gray-400">Loading...</p>
        </div>
      </div>
    );
  }

  const isAuthenticated = currentUser !== null;

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/terms" element={<Terms />} />
        <Route 
          path="/login" 
          element={
            isAuthenticated ? (
              <Navigate to="/dashboard" replace />
            ) : (
              <Login onLogin={() => {
                // Authentication is handled by authService
                // This callback is just for triggering navigation
              }} />
            )
          } 
        />
        
        <Route
          path="/*"
          element={
            isAuthenticated ? (
              <MainLayout>
                <Routes>
                  <Route path="/dashboard" element={<Dashboard />} />
                  
                  <Route path="/agents" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <AgentManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/agents/:id" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <AgentDetail />
                    </RoleGuard>
                  } />
                  
                  <Route path="/admin-management" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <AdminManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/agent-approval" element={
                    <RoleGuard allowedRoles={['super_admin', 'admin']}>
                      <AgentApproval />
                    </RoleGuard>
                  } />
                  
                  <Route path="/services" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <ServiceManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/side-categories" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <SideCategoryManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/banners" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <BannerManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/announcements" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <AnnouncementManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/document-requirements" element={<Navigate to="/services" replace />} />
                  
                  <Route path="/customer-verification" element={<Navigate to="/dashboard" replace />} />

                  <Route path="/application/:applicationId" element={
                    <RoleGuard allowedRoles={['super_admin', 'admin']}>
                      <ApplicationDetail />
                    </RoleGuard>
                  } />
                  
                  <Route path="/certificate-generation" element={
                    <RoleGuard allowedRoles={['super_admin', 'admin']}>
                      <CertificateGeneration />
                    </RoleGuard>
                  } />
                  
                  <Route path="/wallet" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <WalletManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/withdrawals" element={
                    <RoleGuard allowedRoles={['super_admin', 'admin']}>
                      <PermissionGuard permission="withdrawalAccess">
                        <WithdrawalManagement />
                      </PermissionGuard>
                    </RoleGuard>
                  } />
                  
                  <Route path="/commission-settings" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <CommissionSettings />
                    </RoleGuard>
                  } />
                  
                  <Route path="/refer-earn" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <ReferEarn />
                    </RoleGuard>
                  } />
                  
                  <Route path="/terms-management" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <TermsManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/registration-settings" element={
                    <RoleGuard allowedRoles={['super_admin']}>
                      <RegistrationSettings />
                    </RoleGuard>
                  } />
                  
                  <Route path="/appointments" element={
                    <RoleGuard allowedRoles={['super_admin', 'admin']}>
                      <AppointmentManagement />
                    </RoleGuard>
                  } />
                  
                  <Route path="/profile" element={<AdminProfile />} />
                  <Route path="/" element={<Navigate to="/dashboard" replace />} />
                </Routes>
              </MainLayout>
            ) : (
              <Navigate to="/login" replace />
            )
          }
        />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
