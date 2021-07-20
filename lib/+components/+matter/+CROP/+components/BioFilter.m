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
        function this = BioFilter(oContainer, sName)
             
            % The store "BioFilter" is implemented as a cylinder with a
            % diameter of 10 cm and a length of 100 cm
            fVolume = pi * (0.1 / 2)^2 * 1.0;
            
            % Create the store "BioFilter" based on the cylinder's volume
            this@matter.store(oContainer, sName, fVolume);
           
            %% FlowPhase
            % The phase "FlowPhase" in the store "BioFilter" which
            % represents the flowing wastewater in the trickling filter
            % with the volume 1 L which is described in section 4.2.2.2. in
            % Sun's thesis.
            % The initial masses of the main reactants are determined with
            % respect to the volume of the "FlowPhase".
            fVolume_FlowPhase = 0.001;
            oFlow   = this.createPhase(    'mixture', 'flow',    'FlowPhase',     'liquid',        fVolume_FlowPhase,       struct('H2O', 1),       293, 1e5);

            %% BioPhase
            % The phase "BioPhase" in the store "BioFilter" which
            % represents the volcanic rocks, the microorganisms as well as 
            % the enzyme reactants on them. The initial masses are nominal
            % mass levels according to Table 4-2 in Sun's thesis.
            oBio = matter.phases.mixture(this, 'BioPhase','liquid', ...
                struct('H2O', 0.1, 'CH4N2O', 1e-4, 'NH3', 1e-4, 'NO2', 1e-4, ...
                'NO3', 1e-4, 'NH4', 1e-4, 'O2',1e-4, 'CO2', 1e-4, 'H', 1e-4), ...
                293.15, 9e4);
            
            %% ExMes
            % Exme processors on the phase "BioPhase"
            matter.procs.exmes.mixture(oBio, 'Bio_P2P_In');
            matter.procs.exmes.mixture(oBio, 'Bio_P2P_Out');

            % Two Exme processors on the phase "FlowPhase"
            matter.procs.exmes.mixture(oFlow, 'In');
            matter.procs.exmes.mixture(oFlow, 'Out');
            
            matter.procs.exmes.mixture(oFlow, 'Flow_P2P_In');
            matter.procs.exmes.mixture(oFlow, 'Flow_P2P_Out');
            
            %% Enzyme Reactions
            % The modular manipulator "Enzyme Reactions" in the "BioFilter" 
            % which represents the biochemical reactions in the CROP
            % system. The manipulator in implemented in the file
            % "Enzyme-Reactions.m" in the folder "+components"
            components.matter.CROP.components.Enzyme_Reactions('Enzyme Reactions', oBio, fVolume);

            %% P2Ps
            % 2 P2P objects to hold the nominal level of the matters  
            % (CH4N2O, NH3, NH4, NO2, NO3, H2O, O2, CO2) in "BioPhase"
            % which is described in the section 4.2.2.2 in Sun's thesis.
            components.matter.P2Ps.ManualP2P(this, 'BiofilterOut',  'BioPhase.Bio_P2P_Out' , 'FlowPhase.Flow_P2P_Out');
            components.matter.P2Ps.ManualP2P(this, 'BiofilterIn',   'BioPhase.Bio_P2P_In' , 'FlowPhase.Flow_P2P_In');
          
        end
    end
end