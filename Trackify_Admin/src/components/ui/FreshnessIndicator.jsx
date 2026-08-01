import React, { useEffect, useState } from 'react';
import { RefreshCw, Clock } from 'lucide-react';

export default function FreshnessIndicator({ updatedAt, isFetching, onRefresh }) {
  const [timeAgo, setTimeAgo] = useState('just now');

  useEffect(() => {
    if (!updatedAt) return;

    const interval = setInterval(() => {
      const seconds = Math.floor((Date.now() - updatedAt) / 1000);
      if (seconds < 5) setTimeAgo('just now');
      else if (seconds < 60) setTimeAgo(`${seconds}s ago`);
      else if (seconds < 3600) setTimeAgo(`${Math.floor(seconds / 60)}m ago`);
      else setTimeAgo(`${Math.floor(seconds / 3600)}h ago`);
    }, 5000); // update text every 5s

    return () => clearInterval(interval);
  }, [updatedAt]);

  // Initial set
  useEffect(() => {
    if (!updatedAt) return;
    const seconds = Math.floor((Date.now() - updatedAt) / 1000);
    if (seconds < 5) setTimeAgo('just now');
    else if (seconds < 60) setTimeAgo(`${seconds}s ago`);
    else setTimeAgo(`${Math.floor(seconds / 60)}m ago`);
  }, [updatedAt, isFetching]); // re-run on fetch state change so it resets instantly

  return (
    <div className="flex items-center space-x-3 text-xs text-trackops-steel font-mono">
      <div className="flex items-center">
        <Clock className="w-3 h-3 mr-1" />
        <span>{updatedAt ? `Updated ${timeAgo}` : 'Loading...'}</span>
      </div>
      
      <button 
        onClick={onRefresh}
        disabled={isFetching}
        className={`p-1.5 rounded bg-trackops-card border border-trackops-border hover:text-white transition-colors flex items-center ${isFetching ? 'opacity-50 cursor-not-allowed text-trackops-green' : 'hover:border-white/20'}`}
        title="Force Refresh"
      >
        <RefreshCw className={`w-3 h-3 ${isFetching ? 'animate-spin' : ''}`} />
      </button>
    </div>
  );
}
