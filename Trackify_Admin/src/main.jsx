import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'react-hot-toast';
import App from './App';
import './index.css';
import { BrandingProvider } from './context/BrandingContext';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

ReactDOM.createRoot(document.getElementById('root')).render(
    <BrowserRouter>
      <QueryClientProvider client={queryClient}>
        <BrandingProvider>
          <Toaster
            position="top-right"
            containerStyle={{ zIndex: 999999 }}
            toastOptions={{
              style: {
                zIndex: 999999,
                background: '#18181B',
                color: '#F4F4F5',
                border: '1px solid #3F3F46',
              },
            }}
          />
          <App />
        </BrandingProvider>
      </QueryClientProvider>
    </BrowserRouter>
);
