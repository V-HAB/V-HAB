classdef valve < solver.matter.iterative.procs.f2f
    %VALVE Rudimentary model of a valve to set the flow rate to zero or full
    
    properties
        %Position of valve, true = open
        bValveOpen;
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        %Length and diameter of valve
        fHydrDiameter_close;
        fHydrDiameter_open;
        fHydrDiam;
        fHydrLength;
        
        %Delta pressure, is needed to set the flow rate to zero
        fDeltaPressure = 0;
        fDeltaPress    = 0;
        
        %Valve does not influence temperature
        fDeltaTemp = 0;
        
        %Is valve active or not? This is needed for one of the solvers
        bActive = true;
    end
    
    methods
        function this = valve(oMT, sName, bValveOpen, fLength)
            % Input parameters:
            %   oMT:            matter table reference [object]
            %   sName:          name of the valve [char]
            %   bValveOpen:     inital value of the valve setting [boolean]
            %   fLength:        hydraulic length of the valve, needed for
            %                   the solver [m]
            
            this@solver.matter.iterative.procs.f2f(oMT, sName);
            
            this.bValveOpen = bValveOpen;
            
            %Default setting of diameter of valve. Through diameter=0, the
            %valve has no influence on the flow rate calculation of the
            %solver, which makes sense because the valve is much thiner
            %and shorter than the pipes around it. So it has in fact no
            %influence on the gas flow if it is open
            this.fHydrDiam=0;
            
            %If the valve closes, we need a negative diameter value which
            %means we need a value which is not zero
            this.fHydrDiameter_close=1;
            
            %If the valve opens again, we need the default setting back
            this.fHydrDiameter_open=0;
            
            %Assigning the length of the valve
            this.fHydrLength=fLength;
            
        end
        
        
        function setValvePos(this, bValveOpen)
            this.bValveOpen = ~~bValveOpen;
        end
        
        function update(this)
            
            %if valve closes, assign delta pressure to erase the pressure
            %difference within the branch
            %if valve opens again, set everything back
            if ~this.bValveOpen
                
                this.fHydrDiam=-this.fHydrDiameter_close;
                this.fDeltaPressure=-this.oBranch.coExmes{1}.getPortProperties();
                
            else
                this.fHydrDiam=this.fHydrDiameter_open;
                this.fDeltaPressure=0;
                
            end
            
            % Need to do this because one solver wants fDeltaPress, the
            % other wants fDeltaPressure... Will be changed in the future.
            % Hopefully...
            this.fDeltaPress = this.fDeltaPressure;
            
        end
        
        function [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, ~)
            
            %if valve closes, assign delta pressure to erase the pressure
            %difference within the branch
            %if valve opens again, set everything back
            if ~this.bValveOpen
                
                %this.fHydrDiam=-this.fHydrDiameter_close;
                %this.fDeltaPressure=-this.oBranch.coExmes{1}.getPortProperties();
                fDeltaPress = inf;
            else
                %this.fHydrDiam=this.fHydrDiameter_open;
                %this.fDeltaPressure=0;
                fDeltaPress = 0;
            end
            
            % Need to do this because one solver wants fDeltaPress, the
            % other wants fDeltaPressure... Will be changed in the future.
            % Hopefully...
            %fDeltaPress = this.fDeltaPressure;
            
            % Dummy valve, so we satisfy the iterative solver with a zero
            fDeltaTemp = 0;
        end
    end
    
end

