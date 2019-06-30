classdef Enzyme_Reactions < matter.manips.substance.stationary
    %The modular manipulator "Enzyme Reactions" in the store "BioFilter".
    %   As is mentioned in the file "BioFilter.m", the manipulator 
    %   "Enzyme Reactions" is implemented in this file. The structure of
    %   the manipulator is described in section 4.2.3 in the thesis.
    
    properties
        % The phase "FlowPhase" where the external reactants mainly exist
        oPhaseFlow;
        
        % A concentration array which contains the concentrations of all 
        % reactants (C_tot in the thesis):
        % 1:H2O, 2:CO2, 3:O2, 4:COH4N2, 5:NH3, 6:NH4OH, 7:HNO2, 8:HNO3,
        % 9:A.E, 10:A.ES, 11:A.I, 12:A.EI, 13:A.ESI, 14:A.EP, 15:A.EPI,
        % 16:B.E, 17:B.ES1, 18:B.I, 19:B.EI, 20:B.ESI1, 21:B.EP, 22:B.EPI,
        % 23:B.ES2, 24:B.ESI2, 25:C.E, 26:C.ES, 27:C.I, 28:C.EI, 29:C.ESI, 
        % 30:C.EP, 31:C.EPI
        afConcentration = zeros(1,31);
        
        % The pH value
        fpH;
        
        % The parameter struct which contains all rate constants 
        % (theta_tot in the thesis)
        tParameter;
        
        % An array containing the experimental temperatue values
        afTemperature;
        
        % The pH activity model
        tpH_Diagram;
        
        % The metal ion balance constant (K_M in the thesis)
        fK_Metal_Ion;

    end
    
    methods
        function this = Enzyme_Reactions(sName, oPhase, oPhaseFlow)
           this@matter.manips.substance.stationary(sName, oPhase);
           
           this.oPhaseFlow = oPhaseFlow;
               
           
           % Load all rate constants and input data(Temperature, pH activity model
           % and initial concentration of internal reactants(enzymes and 
           % enzyme-related reactants))
           sFullpath = mfilename('fullpath');
           [sFile,~,~] = fileparts(sFullpath);
           load([sFile '\Parameter.mat'], 'tReaction');
           load([sFile '\pH_model.mat'], 'tpH_Diagram');
           load([sFile '\Initial_Settings.mat'], 'tfInitial_Settings');
           
           asFile_Path = strsplit(sFile,'\');
           iLen_File_Path = length(asFile_Path);
           sPath = strjoin(asFile_Path(1,1:(iLen_File_Path-1)),'\');
           load([sPath '\+validation\Data_Experiment.mat']);
                           

           % Rate constants
           this.tParameter = tReaction;
           
           % The metal ion balance constant (K_M in the thesis)
           this.fK_Metal_Ion = tfInitial_Settings.fK_Metal_Ion;
           
           
           % The concentration of enzyme E and inhibitor I, unit: mol/l
           % Attention: these reactants are not modelled as a matter in
           % the matter table in phases
           
           % Enzyme reaction A
           this.afConcentration(9) = tfInitial_Settings.tfConcentration.AE; % A.E
           this.afConcentration(11) = tfInitial_Settings.tfConcentration.AI; % A.I
           this.afConcentration(12) = tfInitial_Settings.tfConcentration.AEI; % A.EI
           
           % Enzyme reaction B
           this.afConcentration(16) = tfInitial_Settings.tfConcentration.BE;
           this.afConcentration(18) = tfInitial_Settings.tfConcentration.BI;
           this.afConcentration(19) = tfInitial_Settings.tfConcentration.BEI;
           
           % Enzyme reaction C
           this.afConcentration(25) = tfInitial_Settings.tfConcentration.CE;
           this.afConcentration(27) = tfInitial_Settings.tfConcentration.CI;
           this.afConcentration(28) = tfInitial_Settings.tfConcentration.CEI;
           
    
           
            % Temperature (experimental)
            this.afTemperature = Data_Modified.(tfInitial_Settings.series).T; 
            
            % The pH activity model which is created in the class file
            % "manual.m" in the folder "+execution"
            this.tpH_Diagram = tpH_Diagram;
           
        end
    end
    methods( Access = protected)
        function update(this)
            
            % The time step of the manipulator in each loop
            fElapsedTime = this.oTimer.fTime - this.fLastExec;
            
            % To avoid numerical oscillation
            if fElapsedTime <= 0.1
                return
            end
            
            % Call the current mass of substances in the phase "FlowPhase"
            afCurrentMasses_Flow = this.oPhaseFlow.afMass;
            afCurrentMasses_Bio = this.oPhase.afMass;
            
            % The molar mass of the substances and their sequences in the
            % matter table
            afMolMass  = this.oPhase.oMT.afMolarMass;
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            % ********************* unit transfer ***********************
            % Unit m^3 transfered to L for the calulation
            fVolume = this.oPhaseFlow.fVolume * 1000; 
            % ***********************************************************

            % Also to avoid numerical oscillation
            if abs(afCurrentMasses_Bio(tiN2I.COH4N2)-1e-4)>0.5e-5 || ...
               abs(afCurrentMasses_Bio(tiN2I.NH3)-1e-4)>0.5e-5 || ...
               abs(afCurrentMasses_Bio(tiN2I.NH4OH)-1e-4)>0.5e-5 || ...
               abs(afCurrentMasses_Bio(tiN2I.HNO2)-1e-4)>0.5e-5 || ...
               abs(afCurrentMasses_Bio(tiN2I.HNO3)-1e-4)>0.5e-5 || ...
               abs(afCurrentMasses_Bio(tiN2I.H2O)-0.1)>0.001
                return;
            end
            
 
            
            % Initialize the array of mass reaction rates
            afPartialFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
                      
            % Calculate the current concentration of all relevant
            % substances. The recalculation takes place
            % because the concentration saved in the variable
            % "afConcentration" in the step before would probabely be changed
            % and is thus not same with the actual
            % concentration in the solution.
            
            % All internal reactants (ES,ESI,EP,EPI) use the mass in "BioPhase", 
            % All external reactants use the mass in "FlowPhase".
            
            this.afConcentration(1) = afCurrentMasses_Flow(tiN2I.H2O) / (afMolMass(tiN2I.H2O) * fVolume);
            this.afConcentration(2) = afCurrentMasses_Flow(tiN2I.CO2) / (afMolMass(tiN2I.CO2) * fVolume);
            this.afConcentration(3) = afCurrentMasses_Flow(tiN2I.O2) / (afMolMass(tiN2I.O2) * fVolume);
            
            this.afConcentration(4)  = afCurrentMasses_Flow(tiN2I.COH4N2) / (afMolMass(tiN2I.COH4N2) * fVolume);
            this.afConcentration(10) = afCurrentMasses_Bio(tiN2I.COH4N2_AES) / (afMolMass(tiN2I.COH4N2_AES) * fVolume); %%% A.ES
            this.afConcentration(13) = afCurrentMasses_Bio(tiN2I.COH4N2_AESI)/ (afMolMass(tiN2I.COH4N2_AESI) * fVolume); %%% A.ESI
            this.afConcentration(5)  = afCurrentMasses_Flow(tiN2I.NH3) / (afMolMass(tiN2I.NH3) * fVolume);
            this.afConcentration(14) = 0.5*afCurrentMasses_Bio(tiN2I.NH3_AEP) / (afMolMass(tiN2I.NH3_AEP) * fVolume); %%% A.EP
            this.afConcentration(15) = 0.5*afCurrentMasses_Bio(tiN2I.NH3_AEPI) / (afMolMass(tiN2I.NH3_AEPI) * fVolume); %%% A.EPI
            this.afConcentration(6)  = afCurrentMasses_Flow(tiN2I.NH4OH) / (afMolMass(tiN2I.NH4OH) * fVolume);
            this.afConcentration(7)  = afCurrentMasses_Flow(tiN2I.HNO2) / (afMolMass(tiN2I.HNO2) * fVolume);
            this.afConcentration(8)  = afCurrentMasses_Flow(tiN2I.HNO3) / (afMolMass(tiN2I.HNO3) * fVolume);
            
            this.afConcentration(17) = afCurrentMasses_Bio(tiN2I.NH4OH_BES) / (afMolMass(tiN2I.NH4OH_BES) * fVolume); %%% B.ES1 ***
            this.afConcentration(20) = afCurrentMasses_Bio(tiN2I.NH4OH_BESI) / (afMolMass(tiN2I.NH4OH_BESI) * fVolume); %%% B.ESI1 ***
            this.afConcentration(23) = afCurrentMasses_Bio(tiN2I.NH3_BES) / (afMolMass(tiN2I.NH3_BES) * fVolume); %%% B.ES2 ***
            this.afConcentration(24) = afCurrentMasses_Bio(tiN2I.NH3_BESI) / (afMolMass(tiN2I.NH3_BESI) * fVolume); %%% B.ESI2 ***
            this.afConcentration(21) = afCurrentMasses_Bio(tiN2I.HNO2_BEP) / (afMolMass(tiN2I.HNO2_BEP) * fVolume); %%% B.EP
            this.afConcentration(22) = afCurrentMasses_Bio(tiN2I.HNO2_BEPI) / (afMolMass(tiN2I.HNO2_BEPI) * fVolume); %%% B.EPI
            
            this.afConcentration(26) = afCurrentMasses_Bio(tiN2I.HNO2_CES) / (afMolMass(tiN2I.HNO2_CES) * fVolume); %%% C.ES
            this.afConcentration(29) = afCurrentMasses_Bio(tiN2I.HNO2_CESI) / (afMolMass(tiN2I.HNO2_CESI) * fVolume); %%% C.ESI
            this.afConcentration(30) = afCurrentMasses_Bio(tiN2I.HNO3_CEP) / (afMolMass(tiN2I.HNO3_CEP) * fVolume); %%% C.EP
            this.afConcentration(31) = afCurrentMasses_Bio(tiN2I.HNO3_CEPI) / (afMolMass(tiN2I.HNO3_CEPI) * fVolume); %%% C.EPI
            
            % Use linear interpolation to calculate the current temperature
            fT = components.matter.CROP.tools.Interpolation_Temperature_Data(this.afTemperature, this.oTimer.fTime);
            
            % Add the effect of temperature to the rate constants which is
            % described in section 4.2.3.7 in the thesis
            tParameter_modified_T = components.matter.CROP.tools.Reaction_Factor_T(this.tParameter, fT);
            
            % ****** Use function to calculate the reaction rates of chemical reaction *********
            % The basic enzyme kinetics is implemented in the file "DiffEquations.m"
            % which is described from section 4.2.3.1 to section 4.2.3.5 in
            % the thesis.
            [this.fpH, afReactionRate] = components.matter.CROP.components.DiffEquations(this.afConcentration, ...
                tParameter_modified_T, this.tpH_Diagram,this.fK_Metal_Ion);
            % ****************************************************************
            
            % Calculate the concentrations of the internal reactants 
            % E, I, EI (reaction A ,B and C) since they are not
            % included in the mass reaction rate conversion below
            for i =[9 11 12 16 18 19 25 27 28]
                this.afConcentration(i) = this.afConcentration(i) + afReactionRate(i) * fElapsedTime;
            end
            
            % Here the molar reaction rates of all reactants are converted
            % to mass reaction rates, because the manipulator uses mass of
            % a matter for calculation but not the concentration.
            
            % Mass reaction rates external reactants
            afPartialFlowRates(this.oMT.tiN2I.COH4N2) = afReactionRate(4) * (afMolMass(tiN2I.COH4N2) * fVolume);
            afPartialFlowRates(this.oMT.tiN2I.NH3) = afReactionRate(5) * (afMolMass(tiN2I.NH3) * fVolume);
            afPartialFlowRates(this.oMT.tiN2I.NH4OH) = afReactionRate(6) * (afMolMass(tiN2I.NH4OH) * fVolume);
            afPartialFlowRates(this.oMT.tiN2I.H2O) = afReactionRate(1) * (afMolMass(tiN2I.H2O) * fVolume);
            afPartialFlowRates(this.oMT.tiN2I.CO2) = afReactionRate(2) * (afMolMass(tiN2I.CO2) * fVolume);
            afPartialFlowRates(this.oMT.tiN2I.O2) = afReactionRate(3) * (afMolMass(tiN2I.O2) * fVolume);
            afPartialFlowRates(this.oMT.tiN2I.HNO2) = afReactionRate(7) * (afMolMass(tiN2I.HNO2) * fVolume);
            afPartialFlowRates(this.oMT.tiN2I.HNO3) = afReactionRate(8) * (afMolMass(tiN2I.HNO3) * fVolume);
            
            % Mass reaction rates of internal reactants
            % of enzyme reaction A (E^A, I^A and EI^A not included, see calculation above)
            afPartialFlowRates(this.oMT.tiN2I.COH4N2_AES) = afReactionRate(10) * (afMolMass(tiN2I.COH4N2_AES) * fVolume); %%% A.ES
            afPartialFlowRates(this.oMT.tiN2I.COH4N2_AESI) = afReactionRate(13) * (afMolMass(tiN2I.COH4N2_AESI) * fVolume); %%% A.ESI
            afPartialFlowRates(this.oMT.tiN2I.NH3_AEP) = 2 * afReactionRate(14) * (afMolMass(tiN2I.NH3_AEP) * fVolume); %%% A.EP
            afPartialFlowRates(this.oMT.tiN2I.NH3_AEPI) = 2 * afReactionRate(15) * (afMolMass(tiN2I.NH3_AEPI) * fVolume);%%% A.EPI
            
            % Mass reaction rates of internal reactants
            % of enzyme reaction B (E^B, I^B and EI^B not included, see calculation above)
            afPartialFlowRates(this.oMT.tiN2I.NH4OH_BES) = afReactionRate(17) * (afMolMass(tiN2I.NH4OH_BES) * fVolume); %%% B.ES1 ***
            afPartialFlowRates(this.oMT.tiN2I.NH4OH_BESI) = afReactionRate(20) * (afMolMass(tiN2I.NH4OH_BESI) * fVolume); %%% B.ESI1 ***
            afPartialFlowRates(this.oMT.tiN2I.NH3_BES) = afReactionRate(30-7) * (afMolMass(tiN2I.NH3_BES) * fVolume); %%% B.ES2 ***
            afPartialFlowRates(this.oMT.tiN2I.NH3_BESI) = afReactionRate(31-7) * (afMolMass(tiN2I.NH3_BESI) * fVolume); %%% B.ESI2 ***
            afPartialFlowRates(this.oMT.tiN2I.HNO2_BEP) = afReactionRate(21) * (afMolMass(tiN2I.HNO2_BEP) * fVolume); %%% B.EP
            afPartialFlowRates(this.oMT.tiN2I.HNO2_BEPI) = afReactionRate(22) * (afMolMass(tiN2I.HNO2_BEPI) * fVolume);%%% B.EPI
            
            % Mass reaction rates of internal reactants
            % of enzyme reaction C (E^C, I^C and EI^C not included, see calculation above)
            afPartialFlowRates(this.oMT.tiN2I.HNO2_CES) = afReactionRate(24+2) * (afMolMass(tiN2I.HNO2_CES) * fVolume); %%% C.ES
            afPartialFlowRates(this.oMT.tiN2I.HNO2_CESI) = afReactionRate(27+2) * (afMolMass(tiN2I.HNO2_CESI) * fVolume); %%% C.ESI
            afPartialFlowRates(this.oMT.tiN2I.HNO3_CEP) = afReactionRate(28+2) * (afMolMass(tiN2I.HNO3_CEP) * fVolume); %%% C.EP
            afPartialFlowRates(this.oMT.tiN2I.HNO3_CEPI) = afReactionRate(29+2) * (afMolMass(tiN2I.HNO3_CEPI) * fVolume);%%% C.EPI
                

            % Check the mass balance for debuging.
            if abs(sum(afPartialFlowRates))>= 1e-7
                keyboard;
            end
            
            update@matter.manips.substance.stationary(this, afPartialFlowRates);
            
            % Negative mass flows in the manip means the substance is
            % consumed and must be added to the phase. Since the P2Ps are
            % both defined as Filter to Flow, a negative flowrate results
            % in an inflow into the filter!
            abInFlow = afPartialFlowRates < 0;
            afInP2PFlows    = zeros(1, this.oMT.iSubstances);
            afInP2PFlows(abInFlow) = afPartialFlowRates(abInFlow);
            
            this.oPhase.oStore.toProcsP2P.BiofilterIn.setFlowRate(afInP2PFlows);
            
            afOutP2PFlows   =  zeros(1, this.oMT.iSubstances);
            afOutP2PFlows(~abInFlow) = afPartialFlowRates(~abInFlow);
            
            this.oPhase.oStore.toProcsP2P.BiofilterOut.setFlowRate(afOutP2PFlows);
        end
    end
end