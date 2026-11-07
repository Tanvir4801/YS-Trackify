import { useEffect, useState } from 'react';
import { useScopeId } from '../store/authStore';
import { subscribeMaterialPurchases, subscribeSiteExpenses, subscribeSuppliers } from '../lib/services/costs.service';
import { subscribeTempLabours } from '../lib/services/tempLabours.service';
import { DEMO_MATERIALS, DEMO_SITE_EXPENSES } from '../lib/demoData';

export function useSiteCosts() {
  const scopeId = useScopeId();
  const isDemo =
    scopeId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true');

  const [materials, setMaterials] = useState(isDemo ? DEMO_MATERIALS : []);
  const [expenses, setExpenses] = useState(isDemo ? DEMO_SITE_EXPENSES : []);
  const [suppliers, setSuppliers] = useState([]);
  const [tempLabours, setTempLabours] = useState([]);
  const [isLoading, setIsLoading] = useState(!isDemo);

  useEffect(() => {
    if (isDemo) {
      setMaterials(DEMO_MATERIALS);
      setExpenses(DEMO_SITE_EXPENSES);
      setSuppliers([]);
      setTempLabours([]);
      setIsLoading(false);
      return undefined;
    }

    if (!scopeId) {
      setMaterials([]);
      setExpenses([]);
      setSuppliers([]);
      setIsLoading(false);
      return undefined;
    }
    
    setIsLoading(true);
    let materialsLoaded = false;
    let expensesLoaded = false;
    let suppliersLoaded = false;
    let tempLaboursLoaded = false;
    
    const checkLoading = () => {
      if (materialsLoaded && expensesLoaded && suppliersLoaded && tempLaboursLoaded) {
        setIsLoading(false);
      }
    };

    const unsubMaterials = subscribeMaterialPurchases(scopeId, (list) => {
      setMaterials(list);
      materialsLoaded = true;
      checkLoading();
    });

    const unsubExpenses = subscribeSiteExpenses(scopeId, (list) => {
      setExpenses(list);
      expensesLoaded = true;
      checkLoading();
    });

    const unsubSuppliers = subscribeSuppliers(scopeId, (list) => {
      setSuppliers(list);
      suppliersLoaded = true;
      checkLoading();
    });

    const unsubTempLabours = subscribeTempLabours(scopeId, (list) => {
      setTempLabours(list);
      tempLaboursLoaded = true;
      checkLoading();
    });

    return () => {
      unsubMaterials();
      unsubExpenses();
      unsubSuppliers();
      unsubTempLabours();
    };
  }, [scopeId]);

  return { materials, expenses, suppliers, tempLabours, isLoading };
}
