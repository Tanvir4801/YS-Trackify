export interface Drawing {
  id: number;
  name: string;
}

export const drawings: Drawing[] = [
  { id: 1, name: 'Final Architectural Plan' },
  { id: 2, name: 'Center Line Marking' },
  { id: 3, name: 'Foundation Details' },
  { id: 4, name: 'Footing Typical Plan' },
  { id: 5, name: 'Plinth Beam Layout' },
  { id: 6, name: 'Ground Beam Details' },
  { id: 7, name: 'Column Starter Bars' },
  { id: 8, name: 'Front Elevation' },
  { id: 9, name: 'Right Side Elevation' },
  { id: 10, name: 'Left Side Elevation' },
  { id: 11, name: 'Ground Floor Working' },
  { id: 12, name: 'Ground Floor Slab & Beams' },
  { id: 13, name: 'Ground Floor Electrical' },
  { id: 14, name: 'First Floor Working' },
  { id: 15, name: 'First Floor Slab & Beams' },
  { id: 16, name: 'First Floor Electrical' },
  { id: 17, name: 'Door/Window Size Schedule' },
  { id: 18, name: 'Terrace Slab & Beam Details' },
  { id: 19, name: 'Terrace Working Details' },
  { id: 20, name: 'Back Side Elevation' },
  { id: 21, name: 'Sanitary & Plumbing Layout' },
  { id: 22, name: 'Revised Final As-Built' },
  { id: 23, name: '3D Perspective Elevation' },
];

export type DrawingStatus = 'pending' | 'completed' | 'delivered';

export const drawingStatusColors: Record<DrawingStatus, string> = {
  pending: 'text-trackify-textMuted',
  completed: 'text-trackify-amber',
  delivered: 'text-trackify-emerald',
};

export const drawingStatusLabels: Record<DrawingStatus, string> = {
  pending: 'Pending',
  completed: 'Completed',
  delivered: 'Delivered',
};

