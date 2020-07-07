classdef Example < vsys
    
    properties (SetAccess = protected, GetAccess = public)
        fHourModuloCounter = 0;
    end
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 30);
            eval(this.oRoot.oCfgParams.configCode(this));
            %connecting subystems
            
            components.matter.WPA.WPA(this, 'WPA');
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
            tfWasteWater = struct('Naplus', 82.725/100,    'Kplus', 11.162/100,    'Ca2plus', 2.2114/100,   'NH4', 7.262/100,    'CMT', 259.505/100,     'Clminus', 76.702/100,   'C4H7O2', 27.597/100,  'C2H3O2', 8.431/100,     'HCO3', 17.27/100,     'SO4', 11.152/100,  'C3H6O3',19.012/100, 'C30H50', 4.700/100,'CH2O2',49.9/100,'C2H6O',39.2/100,'C3H8O2',35.4/100,'CH2O',5.89/100,'C2H6O2',5.51/100,'C3H6O',4.41/100,'CH4N2O',3.55/100,'H2O', 1000*10 );
            
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
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % We initially fill the WPA with 70% of its waste water
            % capacity so that it quickly starts processing water
            fInitialWasteWaterFill = 0.7 * 150 * 0.453592;
            solver.matter.manual.branch(this.toBranches.WasteWaterToWPA);
            this.toBranches.WasteWaterToWPA.oHandler.setMassTransfer(fInitialWasteWaterFill, 300);
            
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            
            exec@vsys(this);
            if this.oTimer.fTime > 300 && this.toBranches.WasteWaterToWPA.fFlowRate == 0
                % Inlet flow represents about 86.4 kg of waste water per day
                this.toBranches.WasteWaterToWPA.oHandler.setFlowRate(0.001);
            end
            
            % This code synchronizes everything once per hour
            if mod(this.oTimer.fTime, 3600) < this.fHourModuloCounter
                this.oTimer.synchronizeCallBacks();
            end
            this.fHourModuloCounter = mod(this.oTimer.fTime, 3600);
        end
    end
end