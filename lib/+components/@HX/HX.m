classdef HX < vsys
%HX Generic heat exchanger model
% With this component it is possible to calculate the outlet temperatures 
% and pressure drops of different heat exchangers
%
% Fluid 1, FlowProc 1 is the one with the fluid flowing through the pipes
% if there are any pipes.
%
% The component uses the following user inputs:
%
% sHX_type with information about what type of heat exchanger should be
% calculated. The possible inputs as strings are:
%           'CounterAnnularPassage'
%           'CounterPlate'
%           'CounterPipeBundle'
%           'ParallelAnnularPassage'
%           'ParallelPlate'
%           'ParallelPipeBundle'
%           'Cross'
%           '3_2_SAT'
%
% The struct tHX_Parameters contains the information about the geometry of
% the heat exchanger. The possible entries are:
%
% for sHX_type = 'CounterAnnularPassage' or 'ParallelAnnularPassage'
%
% tHX_Parameters is a struct with the fields:
% fInnerDiameter         = outer diameter of the inner pipe in m
% fOuterDiameter         = inner diameter of the outer pipe in m
% fInternalRadius        = inner radius of the inner pipe in m
% fLength                = length of the pipe in m
%
%for sHX_type = 'CounterPlate' or 'ParallelPlate'
%
% tHX_Parameters is a struct with the fields:
%fBroadness       = broadness of the heat exchange area in m;
%fHeight_1        = Height of the channel for fluid 1 in m;
%fHeight_2        = Height of the channel for fluid 2 in m;
%fLength          = length of the heat exchanger in m;
%fThickness       = thickness of the plate in m;
%
%for sHX_type = 'CounterPipeBundle' or 'ParallelPipeBundle'
%
% tHX_Parameters is a struct with the fields:
% fInnerDiameter           = inner diameter of the pipes in m
% fOuterDiameter           = outer diameter of the pipes in m
% fShellDiameter           = inner diameter of the shell around the pipes in m
% fLength                  = length of the HX in m
% iNumberOfPipes           = number of pipes
% fPerpendicularSpacing    = distance between the center of two pipes next 
%                            to each other perpendicular to flow direction in m
% fParallelSpacing         = distance between the center of two pipes next 
%                            to each other in flow direction in m
%
%for sHX_type = 'cross'
%
%for number of pipes = 0 tHX_Parameters is a struct with the fields:
%fBroadness       = broadness of the heat exchange area in m;
%fHeight_1        = Height of the channel for fluid 1 in m;
%fHeight_2        = Height of the channel for fluid 2 in m;
%fLength          = length of the heat exchanger in m;
%fThickness       = thickness of the plate in m;
%
%for number of pipes >0 tHX_Parameters is a struct with the fields:
% iNumberOfRows            = number of pipe rows
% iNumberOfPipes           = number of pipes
% fInnerDiameter           = inner diameter of the pipes in m
% fOuterDiameter           = outer diameter of the pipes in m
% fLength                  = length of the pipes in m
% fPerpendicularSpacing    = distance between the center of two pipes next
%                            to each other perpendicular to flow direction in m
% fParallelSpacing         = distance between the center of two pipes next 
%                            to each other in flow direction in m
% iConfiguration           = parameter to check the configuration,for
%                            fConfig = 0 it is assumed that the pipes are
%                            aligend.For fConfig = 1 it is assumed that
%                            they are shiffted with the pipes of each row
%                            shiffted exactly with fs_1/2. For fConfig = 2
%                            a partially shiffted configuration is assumed.
% fPipeRowOffset           = distance between the center of two pipes,
%                            which are in different rows, measured
%                            perpendicular to flow direction in m.
%
%
%for sHX_type = '3 2 sat' tHX_Parameters is a struct with the fields:
%
% fInnerDiameter              = inner diameter of the pipes in m (if x fOuterDiameter is required)
% fLength                     = length of the pipes in m
% fOuterDiameter              = outer diameter of the pipes in m (if x fInnerDiameter is required)
% fBaffleDiameter             = diameter of the baffles
% fBatchDiameter              = outer diameter of the pipe batch
% fHoleDiameter               = diameter of the holes in the baffles
%                               through which the pipes pass
% fShellDiameter              = inner diameter of the shell
% fInnerDiameterInterface     = inner diameter of interface fittings in m
% fLengthInterfaceFitting     = length of interface fittings in m
% fPerpendicularSpacing       = distance between the center of two pipes
%                               next to each other perpendicular to flow
%                               direction in m
% fParallelSpacing            = distance between the center of two pipes 
%                               next to each other in flow direction in m
% iNumberOfPipes              = total number of pipes in the heat exchanger
% iNumberOfPipesInWindow      = number of pipes in the window left by a baffle
% iNumberOfResistances        = number of main flow resistances in the transverse zone
%                               (see [9] section Gh 4 Bild 6 for instruction on how to
%                               count them)
% iNumberOfResistancesEndZone = number of main flow resistances in the endzone
% iNumberOfSealings           = number of sealing strip pairs, between pipes and shell
% iNumberOfPipes_Diam         =  number of pipes at the diameter, counted parallel to baffle edges.
% fBaffleDistance             = distance between baffles in m
% fBaffleHeight               = Height of baffles
% iConfiguration              = parameter to check the configuration,for
%                               fConfig = 0 it is assumed that the pipes
%                               are aligend.For fConfig = 1 it is assumed
%                               that they are shiffted with the pipes of
%                               each row shiffted exactly with fs_1/2. For
%                               fConfig = 2 a partially shiffted
%                               configuration is assumed.
% fPipeRowOffset              = distance between the center of two pipes,
%                               which are in different rows, measured
%                               perpendicular to flow direction in m.
%
%every input marked with (x) above can be set to the string 'x' in order to
%use assumptions to fill that value.
%
%Additionally the thermal conductivity of the heat exchanger material is
%needed.
%Conductivity_Solid = thermal conductivity of heat exchanger material
%                     through which heat is exchanged in W/(m K)
%If infinte is used for this value no thermal resistance from
%conductance is assumed.
%
%these inputs are used in the component call as follows:
%
%HX(oParent, sName, tHX_Parameters, sHX_type, fHX_TC, fTempChangeToRecalc, rChangeToRecalc)
%
% The parameter fTempChangeToRecalc represents the allowed temperature
% change in K before the HX is recalculated while the parameter 
% rChangeToRecalc represents percentual values for the other changes (e.g.
% matter composition)
 
    properties 
        %flow to flow processors for fluid 1 and 2 to set outlet temp and
        %pressure
        oF2F_1; 
        oF2F_2;
        
        %User Inputs for the geometry of the heat exchanger (see hx_main
        %for more information)
        tHX_Parameters;
        
        %User input for the type of heat exchanger (see hx_man for more
        %information)
        sHX_type;
        
        %Outlet temperatures of the heat exchangers. These two variables
        %don't directly serve any purpose but can be used to plot the
        %outlet temperature directly behind the heat exchanger
        fTempOut_Fluid1;
        fTempOut_Fluid2;
        %Old Values for the previous iteration
        fEntryTemp_Old_1;
        fEntryTemp_Old_2;
        fMassFlow_Old_1;
        fMassFlow_Old_2;
        arPartialMass1Old;
        arPartialMass2Old;
        fOldPressureFlow1;
        fOldPressureFlow2;
        
        %variable to check wether it is the first iteration step
        iFirst_Iteration = int8(1);
        
        %TODO Replace the following with the heat exchanger material, the
        %conductivity can then be gathered from the matter table. 
        fHX_TC = Inf;    %Heat exchanger material thermal conductivity
        %initialies for infinite because in this case there is no thermal
        %resistance from conductance
        
        % Stores the time at which the update() method was last called
        fLastUpdate = -1;
        
        fTempChangeToRecalc = 0.05;
        rChangeToRecalc     = 0.01;
    end
    
    methods
        function this = HX(oParent, sName, tHX_Parameters, sHX_type, fHX_TC, fTempChangeToRecalc, rChangeToRecalc)
            this@vsys(oParent, sName);
            
            %if a thermal conductivity for the heat exchanger is provided
            %it overrides the infinte value with which it is initialised
            if nargin > 4
                this.fHX_TC = fHX_TC;
            end
          
            this.tHX_Parameters = tHX_Parameters;
            % To simplify code maintainability the parallel and counter
            % flow options are not differentiated in their subfunctions
            if ~isempty(regexp(sHX_type, 'Parallel', 'once'))
                this.tHX_Parameters.bParallelFlow = true;
                this.sHX_type = erase(sHX_type, "Parallel");
                
            elseif ~isempty(regexp(sHX_type, 'Counter', 'once'))
                this.tHX_Parameters.bParallelFlow = false;
                this.sHX_type = erase(sHX_type, "Counter");
                
            else
                this.sHX_type = sHX_type;
            end
            
            this.bExecuteContainer = false;
            if nargin > 5
                this.fTempChangeToRecalc = fTempChangeToRecalc;
                this.rChangeToRecalc = rChangeToRecalc;
            end
            %Because the HX f2f proc is actually added to the parent system
            %of the HX its definition has to take place here instead of the
            %createMatterStructure function
            
            %adds the flow to flow processores used to set the outlet
            %values of the heat exchanger
            this.oF2F_1 = components.HX.hx_flow(this, this.oParent, [this.sName,'_1']);
            this.oF2F_2 = components.HX.hx_flow(this, this.oParent, [this.sName,'_2']);
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
        end
        

    end
    
    methods
        
        function update(this)
            
            % We skip the very first update because some of the flow rates
            % are still zero.
            if ~this.oTimer.fTime
                return;
            end
            
            % Get the two flow objects from the heat exchanger, flow 1 
            % always has to be the one inside the pipes if there are pipes
            
            % getInFlow() will produce an error if the flow rate is zero.
            % To avoid this, we try to do it "right", if it doesn't work,
            % we'll just take the fist flow. 
            try
                oFlows_1 = this.oF2F_1.getInFlow(); 
            catch
                oFlows_1 = this.oF2F_1.aoFlows(1);
            end
            
            try
                oFlows_2 = this.oF2F_2.getInFlow(); 
            catch
                oFlows_2 = this.oF2F_2.aoFlows(1);
            end
            
            % gets the values from the flows required for the HX
            fMassFlow_1  = abs(oFlows_1.fFlowRate);      % Get absolute values, hope that's okay...
            fMassFlow_2  = abs(oFlows_2.fFlowRate);      % Get absolute values, hope that's okay...
            
            if (fMassFlow_1 == 0) || (fMassFlow_2 == 0)
                this.oF2F_1.setOutFlow(0, 0);
                this.oF2F_2.setOutFlow(0, 0);
                return
            end
            
            fEntryTemp_1 = oFlows_1.fTemperature;
            fEntryTemp_2 = oFlows_2.fTemperature;
            
            fCp_1 = oFlows_1.fSpecificHeatCapacity;
            fCp_2 = oFlows_2.fSpecificHeatCapacity;
            
            % For changes in entry temperature that are larger than 0.1 K or
            % changes in massflow which are larger than 1 g/sec the heat
            % exchanger is calculated anew
            % alternativly in the first iteration step the value first is 1
            % and the programm has to calculate the heat exchanger
            if  this.iFirst_Iteration == 1 ||...                                                                    %if it is the first iteration
                (abs(fEntryTemp_1-this.fEntryTemp_Old_1) > this.fTempChangeToRecalc) ||...                          %if entry temp changed by more than X°
                (abs(1-(fMassFlow_1/this.fMassFlow_Old_1)) > this.rChangeToRecalc) ||...                 	%if mass flow changes by more than X%
                (abs(fEntryTemp_2-this.fEntryTemp_Old_2) > this.fTempChangeToRecalc)||...                           %if entry temp changed by more than X°
                (abs(1-(fMassFlow_2/this.fMassFlow_Old_2)) > this.rChangeToRecalc)||...                      %if mass flow changes by more than X%
                (max(abs(1-(oFlows_1.arPartialMass./this.arPartialMass1Old))) > this.rChangeToRecalc)||...  	%if composition of mass flow changed by more than X%
                (max(abs(1-(oFlows_2.arPartialMass./this.arPartialMass2Old))) > this.rChangeToRecalc)||...   %if composition of mass flow changed by more than X%
                (abs(1-(oFlows_1.fPressure/this.fOldPressureFlow1)) > this.rChangeToRecalc)||...             %if Pressure changed by more than X%
                (abs(1-(oFlows_2.fPressure/this.fOldPressureFlow2)) > this.rChangeToRecalc)                  %if Pressure changed by more than X%
                
                fDensity_1      = this.oMT.calculateDensity(oFlows_1);
                fDensity_2      = this.oMT.calculateDensity(oFlows_2);

                fDynVisc_1      = this.oMT.calculateDynamicViscosity(oFlows_1);
                fConductivity_1 = this.oMT.calculateThermalConductivity(oFlows_1);

                fDynVisc_2      = this.oMT.calculateDynamicViscosity(oFlows_2);
                fConductivity_2 = this.oMT.calculateThermalConductivity(oFlows_2);

                % sets the structs for the two fluids according to the
                % definition from HX_main
                Fluid_1 = struct();
                Fluid_1.fMassflow             	= fMassFlow_1;
                Fluid_1.fEntryTemperature       = fEntryTemp_1;
                Fluid_1.fDynamicViscosity       = fDynVisc_1;
                Fluid_1.fDensity                = fDensity_1;
                Fluid_1.fThermalConductivity    = fConductivity_1;
                Fluid_1.fSpecificHeatCapacity 	= fCp_1;

                Fluid_2 = struct();
                Fluid_2.fMassflow               = fMassFlow_2;
                Fluid_2.fEntryTemperature       = fEntryTemp_2;
                Fluid_2.fDynamicViscosity       = fDynVisc_2;
                Fluid_2.fDensity                = fDensity_2;
                Fluid_2.fThermalConductivity    = fConductivity_2;
                Fluid_2.fSpecificHeatCapacity   = fCp_2;
                    
                
                % function call for HX_main to get outlet values as first 
                % value the this struct from object HX is given to the 
                % function HX_main
                [fTempOut_1, fTempOut_2, fDeltaPress_1, fDeltaPress_2] = ...
                    this.(this.sHX_type)(this.tHX_Parameters, Fluid_1 ,Fluid_2 ,this.fHX_TC);

                % sets the outlet temperatures into the respective variable
                % inside the heat exchanger object for plotting purposes
                this.fTempOut_Fluid1 = fTempOut_1;
                this.fTempOut_Fluid2 = fTempOut_2;
                
                % Calculating the heat flows for both hx_flow objects
                fHeatFlow_1 = fMassFlow_1 * fCp_1 * (fTempOut_1 - fEntryTemp_1);
                fHeatFlow_2 = fMassFlow_2 * fCp_2 * (fTempOut_2 - fEntryTemp_2);
                
                % uses the function defined in flowcomps.hx_flow to set the
                % outlet values
                this.oF2F_1.setOutFlow(fHeatFlow_1, fDeltaPress_1);
                this.oF2F_2.setOutFlow(fHeatFlow_2, fDeltaPress_2);

                % sets the variable to decide wether it is the first
                % iteration step to zero
                if this.iFirst_Iteration == 1
                    this.iFirst_Iteration = int8(0);
                end
                
                % Assignes the values of this iteration step as the old values
                % for the next step
                this.fEntryTemp_Old_1    = fEntryTemp_1;
                this.fEntryTemp_Old_2    = fEntryTemp_2;
                this.fMassFlow_Old_1     = fMassFlow_1;
                this.fMassFlow_Old_2     = fMassFlow_2;
                this.arPartialMass1Old = oFlows_1.arPartialMass;
                this.arPartialMass2Old = oFlows_2.arPartialMass;
                this.fOldPressureFlow1 = oFlows_1.fPressure;
                this.fOldPressureFlow2 = oFlows_2.fPressure;
            end
            
            this.fLastUpdate = this.oTimer.fTime; 
            
        end
    end
end


