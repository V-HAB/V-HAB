classdef valve < matter.procs.f2f
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
    end
    
    methods
        function this = valve(oContainer, sName, bValveOpen, fLength)
            % Input parameters:
            %   sName:          name of the valve [char]
            %   bValveOpen:     inital value of the valve setting [boolean]
            %   fLength:        hydraulic length of the valve, needed for
            %                   the solver [m]
            
            this@matter.procs.f2f(oContainer, sName);
            
            this.bValveOpen = bValveOpen;
            
            
            %If the valve closes, we need a negative diameter value which
            %means we need a value which is not zero
            this.fHydrDiameter_close=1;
            
            %If the valve opens again, we need the default setting back
            this.fHydrDiameter_open=0;
            
            %Default setting of diameter of valve. Through diameter=0, the
            %valve has no influence on the flow rate calculation of the
            %solver, which makes sense because the valve is much thiner
            %and shorter than the pipes around it. So it has in fact no
            %influence on the gas flow if it is open
            this.fHydrDiam=sif(this.bValveOpen, this.fHydrDiameter_open, this.fHydrDiameter_close);
            
            
            %Assigning the length of the valve
            this.fHydrLength=fLength;
            
            
            
            this.supportSolver('hydraulic', this.fHydrDiam, this.fHydrLength, true, @this.update);
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
        end
        
        
        function setValvePos(this, bValveOpen)
            this.bValveOpen = ~~bValveOpen;
            
            
            this.oBranch.setOutdated();
        end
        
        function fDeltaPressure = update(this)
            oHydr = this.toSolve.hydraulic;
            
            %if valve closes, assign delta pressure to erase the pressure
            %difference within the branch
            %if valve opens again, set everything back
            if ~this.bValveOpen
                
                oHydr.fHydrDiam=-this.fHydrDiameter_close;
                fDeltaPressure=-this.oBranch.coExmes{1}.getPortProperties();
                
            else
                oHydr.fHydrDiam=this.fHydrDiameter_open;
                fDeltaPressure=0;
                
            end
            
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

