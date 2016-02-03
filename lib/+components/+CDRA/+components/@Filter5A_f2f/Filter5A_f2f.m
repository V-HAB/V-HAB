classdef Filter5A_f2f < matter.procs.f2f
    
    %This f2f proc is used to model the thermal exchange between the air
    %flow and the zeolite.
    
    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam = 1;          % Hydraulic diameter
        fHydrLength = 1;        % This just has to be there because of parent class and solver, value is irrelevant
        fDeltaTemp = 0;         % Temperature difference created by the component in [K]
        fDeltaPress = 0;        % Pressure difference created by the component in [Pa]
        bActive = true;         % Must be true so the update function is called from the branch solver
       
        oFilter;
        
        
        fLastExec = 0;
    end
    
    methods
        function this = Filter5A_f2f(oMT, sName, oFilter)
            this@matter.procs.f2f(oMT, sName);
            
            this.oFilter = oFilter;
            
            this.supportSolver('manual', true, @this.update);
        end
        
        function update(this)
            
            fTimeStep = this.oBranch.oContainer.oTimer.fTime - this.fLastExec;
            if fTimeStep <= 0
                return
            end
            
            if this.aoFlows(1,1).fFlowRate == 0
                return
            elseif this.aoFlows(1,1).fFlowRate > 0
                oInFlow = this.aoFlows(1,1);
            else
                oInFlow = this.aoFlows(1,2);
            end
            fDensity = this.oMT.calculateDensity(oInFlow);
            fDynVisc = this.oMT.calculateDynamicViscosity(oInFlow);
            fThermCond = this.oMT.calculateThermalConductivity(oInFlow);
            
            %Assuming that 90% of the area is blocked by zeolite
            fFlowArea = 0.1*0.3048*0.254; % --> 10% * 0.3048m * 0.254m
            
            fFlowSpeed = abs(oInFlow.fFlowRate/(fFlowArea*fDensity));
            
            %Calculates the heat exchanger coeffcient between the flow and
            %the zeolite. Using the function for the convection at a plate
            %may not be entirely correct, but it is definitly better than
            %the previous calculations using natural convection.
            fConvection_alpha = convection_plate (1.0922, fFlowSpeed,...
                         fDynVisc, fDensity, fThermCond, this.oFilter.toPhases.FilteredPhase.fTemperature);
            
            sFilterP2P = this.oFilter.csProcsP2P{1};
                     
            this.fHeatFlow = this.oFilter.toProcsP2P.(sFilterP2P).fEffectiveZeoliteArea*fConvection_alpha*(this.oFilter.toPhases.FilteredPhase.fTemperature-oInFlow.fTemperature);
            
            this.fDeltaTemp = this.fHeatFlow/(oInFlow.fFlowRate*oInFlow.fSpecificHeatCapacity);
            %The temperature difference has to remain within certain limits
            %for high time steps to prevent unphysical behavior
            
            %if the temperature of the solid phase is higher than the
            %flow temperature
            if this.oFilter.toPhases.FilteredPhase.fTemperature >= oInFlow.fTemperature
                %With the temperature difference the flow temp would
                %increase the flow temperature above the solid phase
                %temperature
                if ((oInFlow.fTemperature + this.fDeltaTemp) > this.oFilter.toPhases.FilteredPhase.fTemperature)
                    %Then the maximum temperature difference is the
                    %difference between the solid temperature and the
                    %flow temperature
                    this.fDeltaTemp = this.oFilter.toPhases.FilteredPhase.fTemperature-oInFlow.fTemperature;
                    this.fHeatFlow = this.fDeltaTemp*(oInFlow.fFlowRate*oInFlow.fSpecificHeatCapacity);
                end
            else
                %the solid is colder than the flow and the temperature
                %difference would decrease the flow temperature below the
                %solid temperature
                if ((oInFlow.fTemperature + this.fDeltaTemp) < this.oFilter.toPhases.FilteredPhase.fTemperature)
                    %Then the maximum temperature difference is the
                    %difference between the solid temperature and the
                    %flow temperature
                    this.fDeltaTemp = this.oFilter.toPhases.FilteredPhase.fTemperature-oInFlow.fTemperature;
                    this.fHeatFlow = this.fDeltaTemp*(oInFlow.fFlowRate*oInFlow.fSpecificHeatCapacity);
                end
            end
            
            this.fLastExec = this.oBranch.oContainer.oTimer.fTime;
        end
        
        
        
        function setActive(this, bActive, ~)
            if nargin < 3
                this.bActive = bActive;
%                 this.fTimeStepPrevious = 1;
            else
                this.bActive = bActive;
%                 this.fTimeStepPrevious = fTime - 1;
            end
        end
    end
end