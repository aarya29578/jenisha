import { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { authService } from '@/services/authService';
import { Shield, AlertTriangle } from 'lucide-react';

interface RoleGuardProps {
  children: ReactNode;
  allowedRoles: Array<'super_admin' | 'admin' | 'moderator'>;
  redirectTo?: string;
}

export default function RoleGuard({ children, allowedRoles, redirectTo = '/dashboard' }: RoleGuardProps) {
  const currentUser = authService.getCurrentUser();

  if (!currentUser) {
    return <Navigate to="/login" replace />;
  }

  const hasAccess = allowedRoles.includes(currentUser.role);

  if (!hasAccess) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center p-6">
        <div className="max-w-md w-full bg-red-50 border-2 border-red-200 rounded-lg p-8 text-center">
          <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <AlertTriangle className="w-8 h-8 text-red-600" />
          </div>
          <h2 className="text-2xl font-bold text-red-800 mb-2">Access Denied</h2>
          <p className="text-red-700 mb-4">
            You don't have permission to access this page.
          </p>
          <div className="flex items-center justify-center gap-2 text-sm text-red-600 mb-6">
            <Shield className="w-4 h-4" />
            <span>Required role: {allowedRoles.join(' or ')}</span>
          </div>
          <button
            onClick={() => window.history.back()}
            className="px-6 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
          >
            Go Back
          </button>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
