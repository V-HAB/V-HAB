classdef HX < vsys
%HX Generic heat exchanger model
% With this component it is possible to calculate the outlet temperatures 
% and pressure drops of different heat exchangers
%
% Fluid 1, FlowProc 1 is the one with the fluid flowing through the pipes
% if there are any pipes.
%
%The component uses the following user inputs:
%
%sHX_type with information about what type of heat exchanger should be
%calculated. The possible inputs as strings are:
%           'counter annular passage'
%           'counter plate'
%           'counter pipe bundle'
%           'parallel annular passage'
%           'parallel plate'
%           'parallel pipe bundle'
%           'cross'
%           '1 n sat'
%           '3 2 sat'
%
%The vector mHX which contains the information about the geometry of the 
%heat exchanger. The possible entries are:
%
%for sHX_type = 'counter annular passage' or 'parallel annular passage'
%
%mHX = [fD_i, fD_o, fR_i, fLength] with the parameters:
%fD_i         = outer diameter of the inner pipe in m
%fD_o         = inner diameter of the outer pipe in m
%fR_i         = inner radius of the inner pipe in m
%fLength      = length of the pipe in m
%
%for sHX_type = 'counter plate' or 'parallel plate'
%
%mHX = [fBroadness, fHeight_1, fHeight_2, fLength, fThickness]
%with the parameters:
%fBroadness       = broadness of the heat exchange area in m;
%fHeight_1        = Height of the channel for fluid 1 in m;
%fHeight_2        = Height of the channel for fluid 2 in m;
%fLength          = length of the heat exchanger in m;
%fThickness       = thickness of the plate in m;
%
%for sHX_type = 'counter pipe bundle' or 'parallel pipe bundle'
%
%mHX=[fD_i, fD_o, fD_s, fLength, fN_Pipes, fs_1, fs_2] with the parameters:
%fD_i         = inner diameter of the pipes in m
%fD_o         = outer diameter of the pipes in m
%fD_s         = inner (hydraulic) diameter of the shell
%fLength      = length of the pipes in m
%fN_Pipes     = number of pipes
%fs_1         = distance between the center of two pipes next to each
%               other perpendicular to flow direction in m
%fs_2         = distance between the center of two pipes next to each
%               other in flow direction in m
%
%for sHX_type = 'cross'
%
%for number of pipes = 0 the parameters are:
%mHX = [0, fBroadness, fHeight_1, fHeight_2, fLength, fThickness] 
%with the parameters:
%fBroadness       = broadness of the heat exchange area in m;
%fHeight_1        = Height of the channel for fluid 1 in m;
%fHeight_2        = Height of the channel for fluid 2 in m;
%fLength          = length of the heat exchanger in m;
%fThickness       = thickness of the plate in m;
%for number of pipes >0
%mHX = [fN_Rows, fN_Pipes, fD_i, fD_o, fLength, fs_1, fs_2, fconfig, fs_3] 
%with the parameters:
%fN_Rows        = number of pipe rows
%fN_Pipes       = number of pipes
%fD_i           = inner diameter of the pipes in m
%fD_o           = outer diameter of the pipes in m
%fLength        = length of the pipes in m
%fs_1           = distance between the center of two pipes next to each
%                 other perpendicular to flow direction in m
%fs_2           = distance between the center of two pipes next to each
%                 other in flow direction in m
%fConfig        = parameter to check the configuration,for fConfig = 0 it
%                 is assumed that the pipes are aligend.For fConfig = 1 it
%                 is assumed that they are shiffted with the pipes of each
%                 row shiffted exactly with fs_1/2. For fConfig = 2 a 
%                 partially shiffted configuration is assumed.  
%parameters only used for fConfig = 2:
%fs_3           = distance between the center of two pipes, which are in 
%                 different rows, measured perpendicular to flow direction 
%                 in m. 
%
% 1 n sat so far still buggy and may yield complex results or wrong results
%Possible problem is zero point calculation in matlab
%for sHX_type = '1 n sat'
%
%mHX = [fLength, fD_s, mD_i(k), mD_o(k), mN_Pipes_Pass(k)]
%fLength            = length of the pipes in m
%fD_s               = shell diameter in m
%mD_i(k)            = inner pipe diameter of the pass k in m
%mD_o(k)            = outer pipe diameter of the pass k in m
%mN_Pipes_Pass(k)   = number of pipes in the pass k
%
%the first two values fLength and fD_s are column vectors with only the 
%first entry not zero. The first entry of these vectors is fLength or fD_s
%The other values are column vectors with the entry for each pass in each
%row.
%Example mHX for a 1,3 HX
%   fLength  ,   fD_s  ,  fD_i(1)  ,  fD_o(1)  ,  mN_Pipes_Pass(1)
%    0       ,    0    ,  fD_i(2)  ,  fD_o(2)  ,  mN_Pipes_Pass(2)
%    0       ,    0    ,  fD_i(3)  ,  fD_o(3)  ,  mN_Pipes_Pass(3)
%
%for sHX_type = '3 2 sat'
%this heat exchanger differs in its input from the other because it
%requires a cell input, which means the inputs have to be set in {}
%
%mHX = {fD_i, fLength, fD_o, fD_Baffle, fD_Batch, fD_Hole, fD_Shell, 
%       fD_Int, fLength_Int, fs_1, fs_2, fN_Pipes, fn_pipes_win,
%       fN_Flow_Resist, fN_Flow_Resist_end, fN_Sealings, fN_Pipes_Diam,
%       fDist_Baffles, fHeight_Baffles, fConfig, fs_3}
%
%fD_i (x)       = inner diameter of the pipes in m (if x fD_o is required)
%fLength        = length of the pipes in m
%fD_o (x)       = outer diameter of the pipes in m (if x fD_i is required)
%fD_Baffle (x)  = diameter of the baffles
%fD_Batch (x)   = outer diameter of the pipe batch
%fD_Hole (x)    = diameter of the holes in the baffles through which the
%                 pipes pass
%fD_Shell       = inner diameter of the shell
%fD_Int         = inner diameter of interface fittings in m
%fLength_Int    = length of interface fittings in m
%fs_1           = distance between the center of two pipes next to each
%                 other perpendicular to flow direction in m
%fs_2           = distance between the center of two pipes next to each
%                 other in flow direction in m
%fN_Pipes       = total number of pipes in the heat exchanger
%fn_pipes_win(x)= number of pipes in the window left by a baffle
%fN_Flow_Resist = number of main flow resistances in the transverse zone
%                 (see [9] section Gh 4 Bild 6 for instruction on how to
%                 count them)
%fN_Flow_Resist_end(x) = number of main flow resistances in the endzone
%fN_Sealings     = number of sealing strip pairs, between pipes and shell
%fN_Pipes_Diam(x)= number of pipes at the diameter, counted parallel to
%                 baffle edges.
%fDist_Baffles   = distance between baffles in m
%fHeight_Baffles = Height of baffles
%fConfig         = parameter to check the configuration,for fConfig = 0 it
%                 is assumed that the pipes are aligend.For fConfig = 1 it
%                 is assumed that they are shiffted with the pipes of each
%                 row shiffted exactly with fs_1/2. For fConfig = 2 a 
%                 partially shiffted configuration is assumed.  
%
%parameters only used for fConfig = 2:
%fs_3           = distance between the center of two pipes, which are in 
%                 different rows, measured perpendicular to flow direction 
%                 in m. 
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
%HX(this, 'componentname', mHX, sHX_type, Conductivity_Solid);

    properties 
        %flow to flow processors for fluid 1 and 2 to set outlet temp and
        %pressure
        oF2F_1; 
        oF2F_2;
        
        %User Inputs for the geometry of the heat exchanger (see hx_main
        %for more information)
        mHX;
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
        fLastUpdate;
        
        fTempChangeToRecalc = 0.1;
        fPercentChangeToRecalc = 0.01;
    end
    
    methods
        function this = HX(oParent, sName, mHX, sHX_type, fHX_TC, fTempChangeToRecalc, fPercentChangeToRecalc)
            this@vsys(oParent, sName);
            
            %if a thermal conductivity for the heat exchanger is provided
            %it overrides the infinte value with which it is initialised
            if nargin > 4
                this.fHX_TC = fHX_TC;
            end
          
            this.mHX = mHX;
            this.sHX_type = sHX_type;      
            this.bExecuteContainer = false;
            if nargin > 5
                this.fTempChangeToRecalc = fTempChangeToRecalc;
                this.fPercentChangeToRecalc = fPercentChangeToRecalc;
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
            
            % We also don't need to do all of the calculations multiple
            % times per timestep, so we do the following check. 
            if this.oTimer.fTime == this.fLastUpdate
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
                (abs(fEntryTemp_1-this.fEntryTemp_Old_1) > this.fTempChangeToRecalc) ||...                          %if entry temp changed by more than X�
                (abs(1-(fMassFlow_1/this.fMassFlow_Old_1)) > this.fPercentChangeToRecalc) ||...                 	%if mass flow changes by more than X%
                (abs(fEntryTemp_2-this.fEntryTemp_Old_2) > this.fTempChangeToRecalc)||...                           %if entry temp changed by more than X�
                (abs(1-(fMassFlow_2/this.fMassFlow_Old_2)) > this.fPercentChangeToRecalc)||...                      %if mass flow changes by more than X%
                (max(abs(1-(oFlows_1.arPartialMass./this.arPartialMass1Old))) > this.fPercentChangeToRecalc)||...  	%if composition of mass flow changed by more than X%
                (max(abs(1-(oFlows_2.arPartialMass./this.arPartialMass2Old))) > this.fPercentChangeToRecalc)||...   %if composition of mass flow changed by more than X%
                (abs(1-(oFlows_1.fPressure/this.fOldPressureFlow1)) > this.fPercentChangeToRecalc)||...             %if Pressure changed by more than X%
                (abs(1-(oFlows_2.fPressure/this.fOldPressureFlow2)) > this.fPercentChangeToRecalc)                  %if Pressure changed by more than X%
                
                fDensity_1      = this.oMT.calculateDensity(oFlows_1);
                fDensity_2      = this.oMT.calculateDensity(oFlows_2);
                
                fDynVisc_1      = this.oMT.calculateDynamicViscosity(oFlows_1);
                fConductivity_1 = this.oMT.calculateThermalConductivity(oFlows_1);
                
                fDynVisc_2      = this.oMT.calculateDynamicViscosity(oFlows_2);
                fConductivity_2 = this.oMT.calculateThermalConductivity(oFlows_2);
                
                % sets the structs for the two fluids according to the
                % definition from HX_main
                Fluid_1.Massflow                = fMassFlow_1;
                Fluid_1.Entry_Temperature       = fEntryTemp_1;
                Fluid_1.Dynamic_Viscosity       = fDynVisc_1;
                Fluid_1.Density                 = fDensity_1;
                Fluid_1.Thermal_Conductivity    = fConductivity_1;
                Fluid_1.Heat_Capacity           = fCp_1;

                Fluid_2.Massflow                = fMassFlow_2;
                Fluid_2.Entry_Temperature       = fEntryTemp_2;
                Fluid_2.Dynamic_Viscosity       = fDynVisc_2;
                Fluid_2.Density                 = fDensity_2;
                Fluid_2.Thermal_Conductivity    = fConductivity_2;
                Fluid_2.Heat_Capacity           = fCp_2;      

                % function call for HX_main to get outlet values as first 
                % value the this struct from object HX is given to the 
                % function HX_main
                [fTempOut_1, fTempOut_2, fDeltaPress_1, fDeltaPress_2] = ...
                    this.HX_main(Fluid_1,Fluid_2,this.fHX_TC);        

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


