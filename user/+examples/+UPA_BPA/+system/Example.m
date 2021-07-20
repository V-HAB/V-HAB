classdef Example < vsys
    %EXAMPLE Example simulation for a CROP filter in V-HAB 2.0
    
    properties (SetAccess = protected, GetAccess = public)
        
        
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            % Adding UPA
            components.matter.UPA.UPA(this,             'UPA');
            
            % Adding BPA
            components.matter.BPA.BPA(this,             'BPA');
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Cabin', 50);
            
            % Adding a phase to the store 'Cabin', 48 m^3 air
            oCabinPhase         = this.toStores.Cabin.createPhase(  'gas', 'boundary',   'CabinAir',  48, struct('N2', 5.554e4, 'O2', 1.476e4, 'CO2', 40),  	293,          0.506);
            
            % Creates a store for the potable water reserve
            % Potable Water Store
            matter.store(this, 'UrineStorage', 1000);
            oUrinePhase = matter.phases.mixture(this.toStores.UrineStorage, 'Urine', 'liquid', struct('Urine', 1.6*1e4), 295, 101325); 
            
            matter.store(this, 'BrineStorage', 0.1);
            oBrinePhase = matter.phases.mixture(this.toStores.BrineStorage, 'Brine', 'liquid', struct('Brine', 0.01), 295, 101325); 
            
            matter.store(this, 'WaterStorage', 1000);
            oWater = this.toStores.WaterStorage.createPhase(  'liquid', 'boundary',   'water',   this.toStores.WaterStorage.fVolume, struct('H2O', 1),          293,          1e5);
           
            % UPA
            matter.branch(this, 'InletUPA',        {}, oUrinePhase);
            matter.branch(this, 'OutletUPA',       {}, oWater);
            matter.branch(this, 'BrineOutletUPA',  {}, oBrinePhase);
            this.toChildren.UPA.setIfFlows('InletUPA', 'OutletUPA', 'BrineOutletUPA');
            
            % BPA
            matter.branch(this, 'BrineInletBPA',    {}, oBrinePhase);
            matter.branch(this, 'AirInletBPA',    	{}, oCabinPhase);
            matter.branch(this, 'AirOutletBPA',     {}, oCabinPhase);
            this.toChildren.BPA.setIfFlows('BrineInletBPA', 'AirInletBPA', 'AirOutletBPA');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = inf;
            tTimeStepProperties.fMaxStep = this.fTimeStep;
            this.toStores.UrineStorage.toPhases.Urine.setTimeStepProperties(tTimeStepProperties);
            this.toStores.BrineStorage.toPhases.Brine.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            % BPA flowrate
            if ~this.toChildren.BPA.bProcessing &&  ~this.toChildren.BPA.bDisposingConcentratedBrine && ~this.toChildren.BPA.toBranches.BrineInlet.oHandler.bMassTransferActive && ~(this.toChildren.BPA.toStores.Bladder.toPhases.Brine.fMass >= this.toChildren.BPA.fActivationFillBPA)
                if this.toStores.BrineStorage.toPhases.Brine.fMass > this.toChildren.BPA.fActivationFillBPA
                    this.toChildren.BPA.toBranches.BrineInlet.oHandler.setMassTransfer(-(this.toChildren.BPA.fActivationFillBPA), 300);
                end
            end
            
            this.oTimer.synchronizeCallBacks();
        end
     end
    
end

