classdef Example < vsys
    
    properties (SetAccess = protected, GetAccess = public)
        fTotalVolumePassedThroughWPA = 0;
        fFlowRateToWPA = 0;
        
        fResyncModuloCounter = 0;
        
        fLastUpdateVolume = 0;
    end
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, -1);
            eval(this.oRoot.oCfgParams.configCode(this));
            %connecting subystems
            
            components.matter.WPA.WPA(this, 'WPA');
            
            % We want to treat a total of x m³
            fTargetVolumeToTreat = (35000/6.33) * 3600 * 7.98e-4 / 1000;
            this.fFlowRateToWPA = (fTargetVolumeToTreat*1000)/86400;
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% stores
            matter.store(this, 'WasteWater',     1500);
            matter.store(this, 'ProductWater',   1500);
            matter.store(this, 'Node_3',     1000000);      %gas part 
            
            matter.store(this, 'WPA_WasteWater_Inlet', 1e-6);
            oWPA_WasteWater_Inlet = this.toStores.WPA_WasteWater_Inlet.createPhase( 'liquid', 'flow', 'WPA_WasteWater_Inlet', 1e-6, struct('H2O', 1), 293, 1e5);
            
            %% phases
            % Watermodel
            % pressure between 5.2e4 and 1.5e5- using 1e5
            % waste water composition
            fWaterMass = 1e6;
            fWaterVolume = fWaterMass/998.24;
            tfWasteWater = struct(  'Naplus',   251e-6  * 1000 * fWaterVolume,...
                                    'Kplus',    23.2e-6 * 1000 * fWaterVolume,...
                                    'Ca2plus',  3.52e-6 * 1000 * fWaterVolume,...
                                    'CMT',      717e-6  * 1000 * fWaterVolume,...
                                    'Clminus',  216e-6  * 1000 * fWaterVolume,...
                                    'C4H7O2',   65.1e-6 * 1000 * fWaterVolume,...
                                    'C2H3O2',   42.5e-6 * 1000 * fWaterVolume,...
                                    'HCO3',     38.4e-6 * 1000 * fWaterVolume,...
                                    'SO4',      25.1e-6 * 1000 * fWaterVolume,...
                                    'H2O',      1e6 );
            
            csFields = fieldnames (tfWasteWater);
            afWasteWaterMass = zeros(1, this.oMT.iSubstances);
            for iComponent = 1:length(csFields)
                afWasteWaterMass(this.oMT.tiN2I.(csFields{iComponent})) = tfWasteWater.(csFields{iComponent});
            end
            
            %gas share in the wastewater
            fPercentGas = 0.10;
            fWasteWaterMass = sum(afWasteWaterMass);
            fGasMass = (fWasteWaterMass / (1 - fPercentGas)) - fWasteWaterMass;
            
            % For this example, assume the gas in the water to be only
            % nitrogen. For other simulations it should be of the same
            % composition as the cabin air approximatly (or rather, the CHX
            % should produce condensate with an air share)
            afWasteWaterMass(this.oMT.tiN2I.N2) = fGasMass;
            
            for iComponent = 1:length(csFields)
                trWasteWaterMassRatios.(csFields{iComponent}) =  tfWasteWater.(csFields{iComponent}) / sum(afWasteWaterMass);
            end
            
            oWasteWater = this.toStores.WasteWater.createPhase( 'mixture',          'Water', 'liquid',        this.toStores.WasteWater.fVolume, trWasteWaterMassRatios,  293, 1e5);
            
            oAtmosphere = this.toStores.Node_3.createPhase(  'gas', 'boundary',     'Air',   this.toStores.Node_3.fVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          293,          0.5);
            
            oProductWater = this.toStores.ProductWater.createPhase( 'mixture',      'Water', 'liquid',        this.toStores.ProductWater.fVolume, struct('H2O', 1),  293, 1e5);
            
            matter.branch(this, oWasteWater, 	{}, oWPA_WasteWater_Inlet, 'WasteWaterToWPA');
            
            matter.branch(this, 'Inlet',        {}, oWPA_WasteWater_Inlet);
            matter.branch(this, 'Outlet',       {}, oProductWater);
            matter.branch(this, 'AirInlet',     {}, oAtmosphere);
            matter.branch(this, 'AirOutlet',    {}, oAtmosphere);
            
            this.toChildren.WPA.setIfFlows('Inlet', 'Outlet', 'AirInlet', 'AirOutlet');
            
            this.toChildren.WPA.setContinousMode(true, this.fFlowRateToWPA)
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            solver.matter.manual.branch(this.toBranches.WasteWaterToWPA);
            
            this.toBranches.WasteWaterToWPA.oHandler.setFlowRate(this.fFlowRateToWPA);
            
            this.toChildren.WPA.switchOffMicrobialCheckValve(true);
            
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            
            exec@vsys(this);
            
            fTimeStep = this.oTimer.fTime - this.fLastUpdateVolume;
            this.fTotalVolumePassedThroughWPA = this.fTotalVolumePassedThroughWPA  + (this.toBranches.WasteWaterToWPA.fFlowRate / this.toBranches.WasteWaterToWPA.aoFlows(1).getDensity) * fTimeStep;
            
            this.fLastUpdateVolume = this.oTimer.fTime;
            
            if mod(this.oTimer.fTime, 1800) < this.fResyncModuloCounter
                this.oTimer.synchronizeCallBacks();
            end
            this.fResyncModuloCounter = mod(this.oTimer.fTime, 1800);
        end
    end
end