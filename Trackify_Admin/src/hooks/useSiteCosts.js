import { useEffect, useState } from 'react';
import { useScopeId } from '../store/authStore';
import { subscribeMaterialPurchases, subscribeSiteExpenses, subscribeSuppliers } from '../lib/services/costs.service';
import { subscribeTempLabours } from '../lib/services/tempLabours.service';

export function useSiteCosts() {
  const scopeId = useScopeId();
  const [materials, setMaterials] = useState([]);
  const [expenses, setExpenses] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [tempLabours, setTempLabours] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
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
