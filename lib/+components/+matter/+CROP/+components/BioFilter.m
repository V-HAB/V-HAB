classdef BioFilter < matter.store
    %The modular store "BioFilter" in the CROP model.
    %   As is mentioned in the system file "CROP.m", the store "BioFilter"
    %   with its three phases "FlowPhase", "BioPhase" and "Atmosphere" is
    %   implemented in this file. The modular manipulator "Enzyme
    %   Reactions" is implemented in the file "Enzyme-Reactions.m" 
    %   in the folder "+components"
    
    properties (SetAccess = protected, GetAccess = public)

    end
    

    methods
        function this = BioFilter(oContainer, sName, ...
                fMass_COH4N2_Inital_Tank, fMass_NH3_Inital_Tank,fMass_NH4OH_Inital_Tank, ...
                fMass_HNO2_Inital_Tank, fMass_HNO3_Inital_Tank, fCon_Mass_NH3_Vapor,...
                fVolume_Tank)
             
            % The store "BioFilter" is implemented as a cylinder with a
            % diameter of 10 cm and a length of 80 cm
            fVolume = pi * (0.1 / 2)^2 * 0.8;
            
            % Create the store "BioFilter" based on the cylinder's volume
            this@matter.store(oContainer, sName, fVolume);
            
            % The phase "FolwPhase" in the store "BioFilter" which
            % represents the flowing wastewater in the trickling filter
            % with the volume 1 L which is described in sectoin 4.2.2.2.
            % The initial masses of the main reactants are determined with
            % respect to the volume of the "FlowPhase".
            fVolume_FlowPhase = 0.001;
            rVolume_Ratio_TankSolution_FlowPhase = fVolume_Tank/fVolume_FlowPhase;
            oFlow  =  matter.phases.mixture(this, 'FlowPhase','liquid',...
                struct('H2O',fVolume_FlowPhase * this.oMT.ttxMatter.H2O.fStandardDensity,...
                'COH4N2', fMass_COH4N2_Inital_Tank/rVolume_Ratio_TankSolution_FlowPhase,...
                'NH3',    fMass_NH3_Inital_Tank   /rVolume_Ratio_TankSolution_FlowPhase,...
                'NH4OH',  fMass_NH4OH_Inital_Tank /rVolume_Ratio_TankSolution_FlowPhase,...
                'HNO2',   fMass_HNO2_Inital_Tank  /rVolume_Ratio_TankSolution_FlowPhase,...
                'HNO3',   fMass_HNO3_Inital_Tank  /rVolume_Ratio_TankSolution_FlowPhase),...
                293.15,1e5);

            % The phase "BioPhase" in the store "BioFilter" which
            % represents the volcanic rocks, the microorganisms as well as 
            % the enzyme reactants on them. The initial masses are nominal
            % mass levels according to Table 4-2 in the thesis.
            oBio = matter.phases.mixture(this, 'BioPhase','liquid', ...
                struct('H2O', 0.1, 'COH4N2', 1e-4, 'NH3', 1e-4, 'HNO2', 1e-4, ...
                'HNO3', 1e-4, 'NH4OH', 1e-4, 'O2',1e-4, 'CO2',1e-4), ...
                293.15,1e5);
            
            matter.procs.exmes.mixture(oBio, 'Bio_P2P_In');
            matter.procs.exmes.mixture(oBio, 'Bio_P2P_Out');
            
            % The phase "Atmosphere" in the store "BioFilter" which 
            % represents the air in the trickling filter
            this.createPhase(  'gas',   'Atmosphere',   fVolume - oBio.fVolume - oFlow.fVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),          293,          0.5);
            
            % Two Exme processors on the phase "FlowPhase"
            matter.procs.exmes.mixture(oFlow, 'In');
            matter.procs.exmes.mixture(oFlow, 'Out');
            
            matter.procs.exmes.mixture(oFlow, 'Flow_P2P_In');
            matter.procs.exmes.mixture(oFlow, 'Flow_P2P_Out');
            
            % The modular manipulator "Enzyme Reactions" in the "BioFilter" 
            % which represents the biochemical reactions in the CROP
            % system. The manipulator in implemented in the file
            % "Enzyme-Reactions.m" in the folder "+components"
            components.matter.CROP.components.Enzyme_Reactions('Enzyme Reactions', oBio, oFlow);

            
            
            % 8 P2P objects to hold the nominal level of the matters  
            % (COH4N2, NH3, NH4OH, HNO2, HNO3, H2O, O2, CO2) in "BioPhase"
            % which is described in the section 4.2.2.2 in the thesis.
            components.matter.P2Ps.ManualP2P(this.oContainer, this, 'BiofilterOut',  'BioPhase.Bio_P2P_Out' , 'FlowPhase.Flow_P2P_Out');
            components.matter.P2Ps.ManualP2P(this.oContainer, this, 'BiofilterIn',   'BioPhase.Bio_P2P_In' , 'FlowPhase.Flow_P2P_In');
            
            % TO DO: saturation of NH3 into the atmosphere must be added
            % again with a good calculation
        end
    end
    

end

