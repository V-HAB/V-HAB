classdef Example < vsys
    %EXAMPLE Example simulation for a CROP filter in V-HAB 2.0
    
    properties (SetAccess = protected, GetAccess = public)
        % Different urine concentrations at which the CROP system is
        % operated. Note that the intended operating condition is 100%
        % but currently insufficient test data for this is available at
        % the TUM-LRT. It is planned to receive additional 100% test
        % data series from DLR and then adjust the model
        mfUrineConcentrations = [3.5, 7, 20, 40, 60, 80, 100] ./ 100;
        % Series:['C' 'H' 'I' 'D' 'E' 'F']
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 300);
            
            for iCROP = 1:length(this.mfUrineConcentrations)
                components.matter.CROP.CROP(this, ['CROP_', num2str(iCROP)]);
            end
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Atmosphere', 1e6);
            oEnvironment = this.toStores.Atmosphere.createPhase( 'gas', 'boundary', 'Environment', 1e6, struct('N2', 8e4, 'O2', 2e4, 'CO2', 400, 'NH3', 1), 293, 0.5);
            
            % Creates a store for the output of the crop systems
            matter.store(this, 'CROP_Solution_Storage', 100);
            oSolutionPhase = matter.phases.liquid(this.toStores.CROP_Solution_Storage, 'Solution', struct('H2O', 0.1), 295, 101325);
            
            matter.store(this,     'CalciteSupply',    1);
            oCalciteSupply = this.toStores.CalciteSupply.createPhase( 'mixture', 'boundary', 'CalciteSupply', 'liquid',  this.toStores.CalciteSupply.fVolume, struct('CaCO3', 1),	293,	1e5);
            
            fWaterMass = 1000;
            fVolume = 1000/998.2;
            
            % Urine concentrations for 100% urine see MA Schalz Table 3-2
            tfConcentration = struct(   'CH4N2O',   15 / 60.06,...
                                        'NH3',      0,...
                                        'NH4',      1.55 / 53.49,...
                                        'Cl',       1.55 / 53.49 + 4.83 / 58.44 + 0.29 / 74.55 + 2 * 0.47 / 203.3,...
                                        'NO2',      0,...
                                        'NO3',      0,...
                                        'C6H5O7', 	0.65 / 293.1,...
                                        'Na',       3 * 0.65 / 293.1 + 4.83 / 58.44 + 2 * 2.37 / 142.04,...
                                        'SO4',      2.37 / 142.04,...
                                        'HPO4',    	4.12 / 174.18,...
                                        'K',        2 * 4.12 / 174.18 + 0.29 / 74.55,...
                                        'Mg',       0.47 / 203.3,...
                                        'Ca',       0.5 / 147.01,...
                                        'CO3',      0);
   
            % Convert the concentrations to masses for calculation since
            % the calculation in V-HAB is based on mass
            afMolMass  = this.oMT.afMolarMass;
            tiN2I      = this.oMT.tiN2I;
    
            for iUrineConcentration = 1:length(this.mfUrineConcentrations)
                
                % Creates a store for the urine
                oStore = matter.store(this, ['UrineStorage_' num2str(iUrineConcentration)], 20);
                oUrinePhase = matter.phases.mixture(oStore, 'Urine', 'liquid', struct('H2O',    fWaterMass,...
                                                                                      'CH4N2O', this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.CH4N2O   * 1000 * fVolume * afMolMass(tiN2I.CH4N2O),...
                                                                                      'NH3',    this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.NH3      * 1000 * fVolume * afMolMass(tiN2I.NH3),...
                                                                                      'NH4',    this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.NH4      * 1000 * fVolume * afMolMass(tiN2I.NH4),...
                                                                                      'NO2',    this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.NO2      * 1000 * fVolume * afMolMass(tiN2I.NO2),...
                                                                                      'NO3',    this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.NO3      * 1000 * fVolume * afMolMass(tiN2I.NO3),...
                                                                                      'Ca2plus',this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.Ca       * 1000 * fVolume * afMolMass(tiN2I.Ca),...
                                                                                      'Clminus',this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.Cl       * 1000 * fVolume * afMolMass(tiN2I.Cl),...
                                                                                      'C6H5O7', this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.C6H5O7   * 1000 * fVolume * afMolMass(tiN2I.C6H5O7),...
                                                                                      'Naplus', this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.Na       * 1000 * fVolume * afMolMass(tiN2I.Na),...
                                                                                      'SO4',    this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.SO4      * 1000 * fVolume * afMolMass(tiN2I.SO4),...
                                                                                      'HPO4',   this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.HPO4     * 1000 * fVolume * afMolMass(tiN2I.HPO4),...
                                                                                      'Kplus',  this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.K        * 1000 * fVolume * afMolMass(tiN2I.K),...
                                                                                      'Mg2plus',this.mfUrineConcentrations(iUrineConcentration) * tfConcentration.Mg       * 1000 * fVolume * afMolMass(tiN2I.Mg))...
                                                                                      , 295, 101325); 
                                                                                  
                matter.branch(this, ['CROP_Urine_Inlet_',       num2str(iUrineConcentration)], 	{ }, oUrinePhase);
                matter.branch(this, ['CROP_Solution_Outlet_',   num2str(iUrineConcentration)],	{ }, oSolutionPhase);
                matter.branch(this, ['CROP_Air_Inlet_',         num2str(iUrineConcentration)], 	{ }, oEnvironment);
                matter.branch(this, ['CROP_Air_Outlet_',        num2str(iUrineConcentration)], 	{ }, oEnvironment);
                matter.branch(this, ['CROP_Calcite_Inlet_',     num2str(iUrineConcentration)], 	{ }, oCalciteSupply);

                this.toChildren.(['CROP_', num2str(iUrineConcentration)]).setIfFlows(   ['CROP_Urine_Inlet_',       num2str(iUrineConcentration)],...
                                                                                        ['CROP_Solution_Outlet_',   num2str(iUrineConcentration)],...
                                                                                        ['CROP_Air_Inlet_',         num2str(iUrineConcentration)],...
                                                                                        ['CROP_Air_Outlet_',        num2str(iUrineConcentration)],...
                                                                                        ['CROP_Calcite_Inlet_',     num2str(iUrineConcentration)]);
            
            end
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;

                    oPhase.setTimeStepProperties(tTimeStepProperties);

                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = inf;
            this.toStores.CROP_Solution_Storage.toPhases.Solution.setTimeStepProperties(tTimeStepProperties);
            this.toStores.CROP_Solution_Storage.toPhases.Solution.oCapacity.setTimeStepProperties(tTimeStepProperties);

            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            this.oTimer.synchronizeCallBacks();
        end
     end
end