import { defineRouter } from '#q-app';
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory,
} from 'vue-router';

import routes from './routes';
import { useAuthStore } from '@/stores/auth-store';
import { recovery } from '@/boot/supabase';

/*
 * If not building with SSR mode, you can
 * directly export the Router instantiation;
 *
 * The function below can be async too; either use
 * async/await or return a Promise which resolves
 * with the Router instance.
 */

export default defineRouter(({ store }) => {
  const createHistory = import.meta.env.QUASAR_SERVER
    ? createMemoryHistory
    : (import.meta.env.QUASAR_VUE_ROUTER_MODE === 'history' ? createWebHistory : createWebHashHistory);

  const Router = createRouter({
    // Beim Zurueck-Gehen die alte Position wiederherstellen, sonst nach oben.
    scrollBehavior: (_to, _from, saved) => saved ?? { left: 0, top: 0 },
    routes,

    // Leave this as is and make changes in quasar.conf.js instead!
    // quasar.conf.js -> build -> vueRouterMode
    // quasar.conf.js -> build -> publicPath
    history: createHistory(import.meta.env.QUASAR_VUE_ROUTER_BASE)
  });

  let authInit: Promise<void> | null = null;

  Router.beforeEach(async (to) => {
    const authStore = useAuthStore(store);
    authInit ??= authStore.init();
    await authInit;

    const requiresAuth = to.matched.some((record) => record.meta.requiresAuth);
    const requiresAdmin = to.matched.some((record) => record.meta.requiresAdmin);
    const isAuthPage = to.path === '/login' || to.path === '/register';

    // Ueber einen "Passwort zuruecksetzen"-Link geoeffnet -> neues Passwort setzen.
    if (recovery.pending && authStore.isAuthenticated) {
      recovery.pending = false;
      if (to.path !== '/reset-password') return '/reset-password';
    }

    if (requiresAuth && !authStore.isAuthenticated) {
      // Ziel merken (z. B. Einladelink), damit es nach dem Login dorthin geht.
      return to.fullPath === '/' ? '/login' : { path: '/login', query: { redirect: to.fullPath } };
    }
    if (requiresAdmin && !authStore.profile?.is_admin) {
      return '/';
    }
    if (isAuthPage && authStore.isAuthenticated) {
      const redirect = typeof to.query.redirect === 'string' ? to.query.redirect : '/';
      return redirect.startsWith('/') ? redirect : '/';
    }
  });

  return Router;
});
