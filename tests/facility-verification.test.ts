import { describe, it, expect, beforeEach } from 'vitest';

// Mock implementation for testing Clarity contracts
const mockClarity = () => {
  let state = {
    facilities: new Map(),
    admin: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM', // Example principal
    blockHeight: 100
  };
  
  return {
    // Mock state getters
    getState: () => state,
    
    // Mock contract functions
    registerFacility: (caller, facilityId, name, location, industryType) => {
      if (state.facilities.has(facilityId)) {
        return { type: 'err', value: 1 };
      }
      
      state.facilities.set(facilityId, {
        owner: caller,
        name,
        location,
        industryType,
        verified: false,
        registrationDate: state.blockHeight,
        verificationDate: null
      });
      
      return { type: 'ok', value: true };
    },
    
    verifyFacility: (caller, facilityId) => {
      if (caller !== state.admin) {
        return { type: 'err', value: 3 };
      }
      
      if (!state.facilities.has(facilityId)) {
        return { type: 'err', value: 2 };
      }
      
      const facility = state.facilities.get(facilityId);
      facility.verified = true;
      facility.verificationDate = state.blockHeight;
      state.facilities.set(facilityId, facility);
      
      return { type: 'ok', value: true };
    },
    
    getFacility: (facilityId) => {
      return state.facilities.get(facilityId) || null;
    },
    
    isFacilityVerified: (facilityId) => {
      const facility = state.facilities.get(facilityId);
      return facility ? facility.verified : false;
    },
    
    setAdmin: (caller, newAdmin) => {
      if (caller !== state.admin) {
        return { type: 'err', value: 3 };
      }
      
      state.admin = newAdmin;
      return { type: 'ok', value: true };
    },
    
    // Helper to advance block height
    advanceBlockHeight: (blocks) => {
      state.blockHeight += blocks;
    },
    
    // Reset state for tests
    resetState: () => {
      state = {
        facilities: new Map(),
        admin: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
        blockHeight: 100
      };
    }
  };
};

describe('Facility Verification Contract', () => {
  let clarity;
  
  beforeEach(() => {
    clarity = mockClarity();
    clarity.resetState();
  });
  
  it('should register a new facility', () => {
    const caller = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    const facilityId = 'facility001';
    
    const result = clarity.registerFacility(
        caller,
        facilityId,
        'Test Facility',
        'Test Location',
        'Manufacturing'
    );
    
    expect(result.type).toBe('ok');
    
    const facility = clarity.getFacility(facilityId);
    expect(facility).not.toBeNull();
    expect(facility.owner).toBe(caller);
    expect(facility.verified).toBe(false);
  });
  
  it('should not register a facility with an existing ID', () => {
    const caller = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    const facilityId = 'facility001';
    
    // Register first time
    clarity.registerFacility(
        caller,
        facilityId,
        'Test Facility',
        'Test Location',
        'Manufacturing'
    );
    
    // Try to register again with same ID
    const result = clarity.registerFacility(
        caller,
        facilityId,
        'Another Facility',
        'Another Location',
        'Chemical'
    );
    
    expect(result.type).toBe('err');
    expect(result.value).toBe(1);
  });
  
  it('should verify a facility when called by admin', () => {
    const caller = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    const admin = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const facilityId = 'facility001';
    
    // Register facility
    clarity.registerFacility(
        caller,
        facilityId,
        'Test Facility',
        'Test Location',
        'Manufacturing'
    );
    
    // Verify facility
    const result = clarity.verifyFacility(admin, facilityId);
    
    expect(result.type).toBe('ok');
    
    const facility = clarity.getFacility(facilityId);
    expect(facility.verified).toBe(true);
    expect(facility.verificationDate).toBe(clarity.getState().blockHeight);
  });
  
  it('should not verify a facility when called by non-admin', () => {
    const caller = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    const nonAdmin = 'ST3CECAKJ4BH08JYY7W53MC81BYDT4YDA5Z7GZLE2';
    const facilityId = 'facility001';
    
    // Register facility
    clarity.registerFacility(
        caller,
        facilityId,
        'Test Facility',
        'Test Location',
        'Manufacturing'
    );
    
    // Try to verify facility as non-admin
    const result = clarity.verifyFacility(nonAdmin, facilityId);
    
    expect(result.type).toBe('err');
    expect(result.value).toBe(3);
    
    const facility = clarity.getFacility(facilityId);
    expect(facility.verified).toBe(false);
  });
  
  it('should check if a facility is verified', () => {
    const caller = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    const admin = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const facilityId = 'facility001';
    
    // Register facility
    clarity.registerFacility(
        caller,
        facilityId,
        'Test Facility',
        'Test Location',
        'Manufacturing'
    );
    
    // Check before verification
    let isVerified = clarity.isFacilityVerified(facilityId);
    expect(isVerified).toBe(false);
    
    // Verify facility
    clarity.verifyFacility(admin, facilityId);
    
    // Check after verification
    isVerified = clarity.isFacilityVerified(facilityId);
    expect(isVerified).toBe(true);
  });
  
  it('should transfer admin rights', () => {
    const admin = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const newAdmin = 'ST3CECAKJ4BH08JYY7W53MC81BYDT4YDA5Z7GZLE2';
    
    // Transfer admin rights
    const result = clarity.setAdmin(admin, newAdmin);
    
    expect(result.type).toBe('ok');
    expect(clarity.getState().admin).toBe(newAdmin);
  });
});
