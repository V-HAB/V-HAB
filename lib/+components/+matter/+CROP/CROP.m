classdef CROP < vsys
    %The system file for the C.R.O.P. system. 
    %   As is described in chapter 4 in the thesis, the CROP system
    %   contains 2 stores "Tank" and "BioFilter". The store "Tank" is
    %   implemented in this file including the phase "TankSolution" and two
    %   Exmes on it ("Tank.In" and "Tank.Out"). The modular "BioFilter" is
    %   implemented in the folder "+components". Two branches
    %   "Tank_to_BioFilter" and "BioFilter_to_Tank" are also implemented in
    %   this file to realize the wastewater circulation between "Tank" and
    %   "BioFilter".
    
    properties

    end
    
    methods
        function this = CROP(oParent, sName)
            this@vsys(oParent, sName, -1);
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % The volume of the store "Tank" is 0.03 m^3
            fVolume_Tank = 0.03;
            
            % Get initial concentrations of main reactants (CH4N2O, NH3, NH4OH, HNO2, HNO3)
            sFullpath = mfilename('fullpath');
            [sFile,~,~] = fileparts(sFullpath);
            asFile_Path = strsplit(sFile,filesep);
            iLen_File_Path = length(asFile_Path);
            sPath = strjoin(asFile_Path(1,1:(iLen_File_Path-1)), filesep);
            load([sPath strrep('\+CROP\+components\Initial_Settings.mat','\',filesep)], 'tfInitial_Settings');
            
            % Convert the concentrations to masses for calculation since
            % the calculation in V-HAB is based on mass
            afMolMass  = this.oMT.afMolarMass;
            tiN2I      = this.oMT.tiN2I;
            fMass_CH4N2O_Inital     = tfInitial_Settings.tfConcentration.CH4N2O * 1000 * fVolume_Tank * afMolMass(tiN2I.CH4N2O);
            fMass_NH3_Inital        = tfInitial_Settings.tfConcentration.NH3 * 1000 * fVolume_Tank * afMolMass(tiN2I.NH3);
            fMass_NH4OH_Inital      = tfInitial_Settings.tfConcentration.NH4OH * 1000 * fVolume_Tank * afMolMass(tiN2I.NH4OH);
            fMass_HNO2_Inital       = tfInitial_Settings.tfConcentration.HNO2 * 1000 * fVolume_Tank * afMolMass(tiN2I.HNO2);
            fMass_HNO3_Inital       = tfInitial_Settings.tfConcentration.HNO3 * 1000 * fVolume_Tank * afMolMass(tiN2I.HNO3);
            
                       
            
            % The store "Tank" in the CROP model which can hold 0.03 m^3 water
            matter.store(this, 'CROP_Tank', fVolume_Tank + 0.001);
            
            % The phase "TankSolution" in the store "Tank" which contains
            % the initial masses of main reactants (CH4N2O, NH3, NH4OH, HNO2, HNO3)
            oTankSolution  =  matter.phases.mixture(this.toStores.CROP_Tank,'TankSolution','liquid',...
                struct('H2O',fVolume_Tank * this.oMT.ttxMatter.H2O.fStandardDensity,...
                'CH4N2O', fMass_CH4N2O_Inital,...
                'NH3', fMass_NH3_Inital,...
                'NH4OH', fMass_NH4OH_Inital,...
                'HNO2', fMass_HNO2_Inital,...
                'HNO3', fMass_HNO3_Inital),...
                293.15, 1e5);
            
            
            % Two Exme processors on the phase "TankSolution"
            matter.procs.exmes.mixture(oTankSolution, 'Tank_Out');
            matter.procs.exmes.mixture(oTankSolution, 'Tank_In');
            matter.procs.exmes.mixture(oTankSolution, 'Urine_In');
            matter.procs.exmes.mixture(oTankSolution, 'Solution_Out');
            
            
            % The modular store "BioFilter" in the CROP model which is
            % implemented in the folder "+components"
            components.matter.CROP.components.BioFilter(this,'CROP_BioFilter', ...
                fMass_CH4N2O_Inital, fMass_NH3_Inital,fMass_NH4OH_Inital, ...
                fMass_HNO2_Inital, fMass_HNO3_Inital, ...
                tfInitial_Settings.fCon_NH3_Vapor * afMolMass(tiN2I.NH3) * 1000,...
                fVolume_Tank);
                        
            % Two branches to realize the wastewater circulation between
            % the two stores
            matter.branch(this, 'CROP_Tank.Tank_Out',       { }, 'CROP_BioFilter.In',       'Tank_to_BioFilter');
            matter.branch(this, 'CROP_BioFilter.Out',       { }, 'CROP_Tank.Tank_In',       'BioFilter_to_Tank');
            
            matter.branch(this, 'CROP_Tank.Urine_In',       { }, 'CROP_Urine_Inlet',        'CROP_Urine_Inlet');
            matter.branch(this, 'CROP_Tank.Solution_Out',   { }, 'CROP_Solution_Outlet',    'CROP_Solution_Outlet');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Use the "manual" solver to solve the two branches
            solver.matter.manual.branch(this.toBranches.Tank_to_BioFilter);
            solver.matter.residual.branch(this.toBranches.BioFilter_to_Tank);
            
            % The interface branches are also set to manual branches.
            % However, the system itself does not tell these what to do,
            % this must be done by the parent system!
            solver.matter.manual.branch(this.toBranches.CROP_Urine_Inlet);
            solver.matter.manual.branch(this.toBranches.CROP_Solution_Outlet);
            
            % Set the flow rate of the wastewater circulation to 1000L/h
            % with the equation Eq.(4-4) in the thesis from Yilun Sun
            this.toBranches.Tank_to_BioFilter.oHandler.setVolumetricFlowRate(1 / 3600);
            
            this.setThermalSolvers();
        end
        function setIfFlows(this, sUrineInlet, sSolutionOutlet)
            this.connectIF('CROP_Urine_Inlet' , sUrineInlet);
            this.connectIF('CROP_Solution_Outlet' , sSolutionOutlet);
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
        end
    end
end