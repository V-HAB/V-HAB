classdef ELY_FC < vsys
    % This is an example model of a fuel cell and an electrolyzer to
    % compare them to literature values. For the fuel cell currently no
    % literature data suitable for verification was identified, therefore
    % it is currently outcommented.
    % This simulation implements multiple electrolyzers and fuel cells to
    % check their behavior at different conditions. A better example on how
    % to implement and combine a single Electrolyzer with a single Fuel
    % cell is the regenrative fuel cell (RFCS) example.
    properties
        % Define the number of cells for the electrolyzer and fuel cell
        iCells          = 300;
        
        % Define the conditions at which the systems shall be simulated:
        mfPressure      = [1, 10, 100]; % bar
        mfTemperature   = 30:10:70; % °C
        mfPower         = 0:1000:100000;
        
        iCurrentPowerTick = 0;
    end
    
    methods
        function this = ELY_FC(oParent, sName)
            
            this@vsys(oParent, sName, 5*60);
            eval(this.oRoot.oCfgParams.configCode(this));
            
            this.mfPower = this.mfPower .* this.iCells;
            
            tInputsEly.iCells               = this.iCells;
            tInputsEly.fMembraneArea        = 1;
            tInputsEly.fMembraneThickness   = 2.1e-4;
            tInputsEly.fMaxCurrentDensity   = 40000;
            
            for iPressure = 1:length(this.mfPressure)
                for iTemperature = 1:length(this.mfTemperature)
                    sElectrolyzer = ['Electrolyzer_', num2str(this.mfPressure(iPressure)), '_', num2str(this.mfTemperature(iTemperature))];
                    components.matter.Electrolyzer.Electrolyzer(this, sElectrolyzer,      5*60, tInputsEly);
                end
            end
            
%             tInputsFC.iCells               = this.iCells;
%             tInputsFC.fMembraneArea        = 1;
%             for iPressure = 1:length(this.mfPressure)
%                 for iTemperature = 1:length(this.mfTemperature)
%                     sFuelCell = ['FuelCell_', num2str(this.mfPressure(iPressure)), '_', num2str(this.mfTemperature(iTemperature))];
%                     components.matter.FuelCell.FuelCell(this, sFuelCell, 5*60, tInputsFC);
%                 end
%             end
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %stores and phases
            % water tank
            
            fInitialTemperature = 293;
            
            matter.store(this, 'Water_Tank', 0.004);
            oWater      = this.toStores.Water_Tank.createPhase(     'liquid',   'boundary',	'Water',   0.004, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            for iTemperature = 1:length(this.mfTemperature)
                sName =  ['CoolingSystem_', num2str(this.mfTemperature(iTemperature))];
                
                matter.store(this, sName, 0.1);
                % Temperature -5 to account for the internal heating of the
                % device which is set to 5 K
                aoCooling(iTemperature)    = this.toStores.(sName).createPhase(  'liquid',	'boundary',	'CoolingWater',  0.1, struct('H2O', 1),  this.mfTemperature(iTemperature) + 273.15 - 5, 1e5); %#ok<AGROW>
            end
            
            for iPressure = 1:length(this.mfPressure)
                sNameH2 =  ['H2_Tank_', num2str(this.mfPressure(iPressure))];
                sNameO2 =  ['O2_Tank_', num2str(this.mfPressure(iPressure))];
                
                matter.store(this, sNameH2, 0.1);
                aoH2(iPressure)         = this.toStores.(sNameH2).createPhase(        'gas',      'boundary', 'H2',   0.1, struct('H2', this.mfPressure(iPressure)*1e5),  fInitialTemperature, 0.8); %#ok<AGROW>

                matter.store(this, sNameO2, 0.05);
                aoO2(iPressure)         = this.toStores.(sNameO2).createPhase(        'gas',      'boundary', 'O2',   0.05, struct('O2', this.mfPressure(iPressure)*1e5),  fInitialTemperature, 0.8); %#ok<AGROW>
            end

            %% Fuel Cell
%             for iPressure = 1:length(this.mfPressure)
%                 for iTemperature = 1:length(this.mfTemperature)
%                     sFuelCell = ['FuelCell_', num2str(this.mfPressure(iPressure)), '_', num2str(this.mfTemperature(iTemperature))];
%                     matter.branch(this, [sFuelCell, '_H2_Inlet'],            {},                             aoH2(iPressure));
%                     matter.branch(this, [sFuelCell, '_O2_Inlet'],            {},                             aoO2(iPressure));
%                     matter.branch(this, [sFuelCell, '_Water_Outlet'],    	 {},                             oWater);
% 
%                     matter.branch(this, [sFuelCell, '_Cooling_Inlet'],       {},                             aoCooling(iTemperature));
%                     matter.branch(this, [sFuelCell, '_Cooling_Outlet'],      {},                             aoCooling(iTemperature));
% 
%                     this.toChildren.(sFuelCell).setIfFlows([sFuelCell, '_H2_Inlet'], [sFuelCell, '_O2_Inlet'], [sFuelCell, '_Cooling_Inlet'], [sFuelCell, '_Cooling_Outlet'], [sFuelCell, '_Water_Outlet'])
%                 end
%             end
            %% Electrolyzer
            for iPressure = 1:length(this.mfPressure)
                for iTemperature = 1:length(this.mfTemperature)
                    sElectrolyzer = ['Electrolyzer_', num2str(this.mfPressure(iPressure)), '_', num2str(this.mfTemperature(iTemperature))];
                    
                    matter.branch(this, [sElectrolyzer, '_H2_Outlet'],          {}, 	aoH2(iPressure));
                    matter.branch(this, [sElectrolyzer, '_O2_Outlet'],          {}, 	aoO2(iPressure));
                    matter.branch(this, [sElectrolyzer, '_Water_Inlet'],        {},  	oWater);

                    matter.branch(this, [sElectrolyzer, '_Cooling_Inlet'],      {},  	aoCooling(iTemperature));
                    matter.branch(this, [sElectrolyzer, '_Coooling_Outlet'],    {},   	aoCooling(iTemperature));
                    
                    this.toChildren.(sElectrolyzer).setIfFlows([sElectrolyzer, '_H2_Outlet'], [sElectrolyzer, '_O2_Outlet'], [sElectrolyzer, '_Water_Inlet'], [sElectrolyzer, '_Cooling_Inlet'], [sElectrolyzer, '_Coooling_Outlet'])
                end
            end
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %% Assign thermal solvers
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            this.iCurrentPowerTick = this.iCurrentPowerTick + 1;
            if this.iCurrentPowerTick > length(this.mfPower)
                this.iCurrentPowerTick = length(this.mfPower);
            end
            
            for iPressure = 1:length(this.mfPressure)
                for iTemperature = 1:length(this.mfTemperature)
                    sElectrolyzer = ['Electrolyzer_', num2str(this.mfPressure(iPressure)), '_', num2str(this.mfTemperature(iTemperature))];
                    
                    this.toChildren.(sElectrolyzer).setPower(this.mfPower(this.iCurrentPowerTick));
                    
%                     sFuelCell     = ['FuelCell_', num2str(this.mfPressure(iPressure)), '_', num2str(this.mfTemperature(iTemperature))];
%                     this.toChildren.(sFuelCell).setPower(this.mfPower(this.iCurrentPowerTick));
                end
            end
            
            
            this.oTimer.synchronizeCallBacks();
        end
    end
end