import { ReactNode, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  UserCheck,
  FolderTree,
  Layers,
  Award,
  Wallet,
  Gift,
  FileSignature,
  Settings,
  Bell,
  User,
  LogOut,
  Menu,
  X,
  Image,
  Shield,
  UserCog,
  Megaphone,
  CalendarDays,
  TrendingUp,
  ArrowDownUp,
} from 'lucide-react';
import { authService } from '@/services/authService';

interface MainLayoutProps {
  children: ReactNode;
}

const navItems = [
  { icon: LayoutDashboard, label: 'Dashboard', path: '/dashboard', roles: ['super_admin', 'admin', 'moderator'] },
  { icon: Users, label: 'Agent Management', path: '/agents', roles: ['super_admin'] },
  { icon: UserCog, label: 'Admin Management', path: '/admin-management', roles: ['super_admin'] },
  { icon: UserCheck, label: 'Agent Approval', path: '/agent-approval', roles: ['super_admin'] },
  { icon: FolderTree, label: 'Services & Categories', path: '/services', roles: ['super_admin'] },
  { icon: Layers, label: 'Side Categories', path: '/side-categories', roles: ['super_admin'] },
  { icon: Image, label: 'Banner Management', path: '/banners', roles: ['super_admin'] },
  { icon: Megaphone, label: 'Announcement Management', path: '/announcements', roles: ['super_admin'] },
  { icon: Award, label: 'Certificate Generation', path: '/certificate-generation', roles: ['super_admin', 'admin'] },
  { icon: Wallet, label: 'Wallet Management', path: '/wallet', roles: ['super_admin'] },
  { icon: ArrowDownUp, label: 'Withdrawal Requests', path: '/withdrawals', roles: ['super_admin'] },
  { icon: TrendingUp, label: 'Commission Settings', path: '/commission-settings', roles: ['super_admin'] },
  { icon: Settings, label: 'Registration Settings', path: '/registration-settings', roles: ['super_admin'] },
  { icon: Gift, label: 'Refer & Earn', path: '/refer-earn', roles: ['super_admin'] },
  { icon: FileSignature, label: 'Terms & Policies', path: '/terms', roles: ['super_admin'] },
  { icon: CalendarDays, label: 'Appointment Management', path: '/appointments', roles: ['super_admin'] },
];

export default function MainLayout({ children }: MainLayoutProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [notifications] = useState(5);
  
  const currentUser = authService.getCurrentUser();

  // Debug: log current user to verify permissions and real-time updates
  if (process.env.NODE_ENV !== 'production') {
    console.log('MainLayout currentUser:', currentUser);
  }

  const handleLogout = async () => {
    try {
      await authService.logout();
      navigate('/login');
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  return (
    <div className="min-h-screen bg-[#0b0f14] text-gray-100 admin-dark-root">
      {/* Top Header */}
      <div className="fixed top-0 left-0 right-0 h-16 bg-[#071018] border-b border-[#0f1720] z-30 shadow-sm">
        <div className="flex items-center justify-between h-full px-4">
          {/* Left Section */}
          <div className="flex items-center gap-4">
            <button
              onClick={() => setIsSidebarOpen(!isSidebarOpen)}
              className="lg:hidden text-gray-200 p-2 hover:bg-[#0f1518] rounded transition-colors"
            >
              {isSidebarOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
            
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-[#243BFF] rounded flex items-center justify-center shadow-md">
                <LayoutDashboard className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-lg text-gray-100">Admin Portal</h1>
                <p className="text-xs text-gray-400">Agent Management System</p>
              </div>
            </div>
          </div>

          {/* Right Section */}
          <div className="flex items-center gap-3">
            {/* Notifications */}
            <Link
              to="/profile"
              className="relative p-2 hover:bg-[#0f1518] rounded transition-colors"
            >
              <Bell className="w-5 h-5 text-gray-300" />
              {notifications > 0 && (
                <span className="absolute -top-1 -right-1 w-5 h-5 bg-[#FF4444] text-white text-xs rounded-full flex items-center justify-center">
                  {notifications}
                </span>
              )}
            </Link>

            {/* Admin Profile */}
            <Link
              to="/profile"
              className="flex items-center gap-2 p-2 hover:bg-[#0f1518] rounded transition-colors"
            >
              <div className="w-8 h-8 bg-[#243BFF] rounded-full flex items-center justify-center shadow-sm">
                {currentUser?.role === 'super_admin' ? (
                  <Shield className="w-4 h-4 text-white" />
                ) : (
                  <User className="w-4 h-4 text-white" />
                )}
              </div>
              <div className="hidden md:block">
                <p className="text-sm text-gray-100">{currentUser?.name || 'Admin User'}</p>
                {currentUser?.role === 'super_admin' && (
                  <p className="text-xs text-[#243BFF]">Super Admin</p>
                )}
              </div>
            </Link>

            {/* Logout */}
            <button
              onClick={handleLogout}
              className="p-2 text-gray-400 hover:bg-[#0f1518] hover:text-red-400 rounded transition-colors"
              title="Logout"
            >
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      {/* Sidebar */}
      <div
        className={`
          fixed top-16 left-0 bottom-0 w-64 bg-[#071018] border-r border-[#111318] z-20
          transition-transform duration-300 ease-in-out
          ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'}
          lg:translate-x-0
        `}
      >
        <div className="h-full overflow-y-auto py-4">
          <nav className="space-y-1 px-3">
            {navItems
              .filter((item) => {
                if (!currentUser) return false;
                // Withdrawal Requests: allow if super_admin OR the permission flag is true
                if (item.path === '/withdrawals') {
                  // Super admin override: always show
                  if (currentUser.role === 'super_admin') return true;
                  // Otherwise require explicit permission
                  return currentUser.permissions?.withdrawalAccess === true;
                }
                return item.roles.includes(currentUser.role);
              })
              .map((item) => {
                const Icon = item.icon;
                const isActive = location.pathname === item.path;
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    onClick={() => setIsSidebarOpen(false)}
                    className={`
                      flex items-center gap-3 px-3 py-3 rounded transition-colors
                      ${isActive 
                        ? 'bg-[#243BFF] text-white shadow-md' 
                        : 'text-gray-300 hover:bg-[#0f1518] hover:text-gray-100'
                      }
                    `}
                  >
                    <Icon className="w-5 h-5 flex-shrink-0" />
                    <span className="text-sm">{item.label}</span>
                  </Link>
                );
              })}
          </nav>
        </div>
      </div>

      {/* Main Content */}
      <div className="pt-16 lg:pl-64">
        <div className="p-6">
          {children}
        </div>
      </div>

      {/* Mobile Overlay */}
      {isSidebarOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-10 lg:hidden"
          onClick={() => setIsSidebarOpen(false)}
        />
      )}
    </div>
  );
}
