classdef valve_pressure_drop < matter.procs.f2f
    %Valve Summary of this class goes here
    %   Detailed explanation goes here
    

    
    properties (SetAccess = protected, GetAccess = public)
        % Used to derive pressure drop based on density, flow rate, coeff
        % Default: no drop at all, except when valve closed!
        fFlowCoefficient = inf; % [???]
        
        % If false, no flow at all (returns inf as pressure drop)
        bOpen = true;
    end
    
    methods
        function  this = valve_pressure_drop(oContainer, sName, fFlowCoefficient, bValveOpen)
            % Input Parameters:
            %   fFlowCoefficient - the bigger, the lower the pressure drop
            %   bValveOpen - if closed, inf pressure drop - no flow!
            
            this@matter.procs.f2f(oContainer, sName);
            
            if nargin >= 3 && ~isempty(fFlowCoefficient)
                this.fFlowCoefficient = fFlowCoefficient;
            end
            
            if nargin >= 4 && ~isempty(bValveOpen)
                this.bOpen = bValveOpen;
            end
            
            
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        
        function setOpened(this)
            this.bOpen = true;
            this.oBranch.setOutdated();
        end
        
        function setClosed(this)
            this.bOpen = false;
            this.oBranch.setOutdated();
        end
        
        function setFlowCoefficient(this, fFlowCoefficient)
            this.fFlowCoefficient = fFlowCoefficient;
            
            this.oBranch.setOutdated();
        end
        
        
        
        function fDeltaPress = solverDeltas(this, fFlowRate)
            if ~this.bOpen || (this.fFlowCoefficient == 0)
                fDeltaPress = inf;
                
                return;
                
            elseif (fFlowRate == 0) || (this.fFlowCoefficient == inf)
                fDeltaPress = 0;
                
                return;
            end
            
            % Get in/out flow object references
            [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);
            
            % No pressure at all ... normally just return, drop zero
            if oFlowIn.fPressure == 0 && oFlowOut.fPressure == 0
                fDeltaPress = 0;
                
                return;
            end
            
            
            % Average density in/out
            fDensityAvg = (oFlowIn.getDensity() + oFlowOut.getDensity()) / 2;
            
            tProps = struct(...
                'fMolarMass',   (oFlowIn.fMolarMass + oFlowOut.fMolarMass) / 2, ...
                'fFlowRate',    fFlowRate, ...
                'fTemperature', (oFlowIn.fTemperature + oFlowOut.fTemperature) / 2, ...
                'fPressure',    (oFlowIn.fPressure + oFlowOut.fPressure) / 2 ...
            );
            
            fSlm = matter.helper.flow.convert.fr.SLM(tProps, false);
            %fSlmHelper = matter.helper.flow.convert.fr.SLM(oFlowIn);
            
            %fFlowRate = fFlowRate * 60; % Convert to kg/min
            %fSlm = (fFlowRate * 60 / oFlowIn.fMolarMass * ...
            %       matter.table.Const.fUniversalGas * oFlowIn.fTemperature / oFlowIn.fPressure) * 1000;
            
            % Slm / Helper the same? MolarMass / 1000 still ok?
            %fprintf('B %s - V %s  FR %f TO SLM    Helper: %f    Inline: %f\n', this.oBranch.sName,  this.sName, fFlowRate, fSlmHelper, fSlm);
            
            % Calculate pressure drop
            fDeltaPress =  fSlm^2 / (fDensityAvg * this.fFlowCoefficient^2);
            
            %fprintf('[%i] %s -> %f ==> %f\n', this.oBranch.oTimer.iTick, this.sName, this.fFlowCoefficient, fDeltaPress);
        end
    end
    
end

