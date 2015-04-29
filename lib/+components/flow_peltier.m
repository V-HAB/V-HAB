classdef flow_peltier < matter.procs.f2f
    %FLOW_PELTIER Flow to flow processor that can heat or cool a flow
    %   Based on the model of a peltier element or thermoelectric cooler
    %   (TEC) wrapped around a flow, or a pipe. Depending on the parameters
    %   it can either increase or decrease the temperature of the flow,
    %   both consume electric energy.
    
    % Properties if proc is being used with the manual solver.
    properties (SetAccess = protected, GetAccess = public)
        fDeltaTemperature  =    0;      % Temperature change from the processor [K]
        bActive            = true;      % Must be true so the update function is called from the branch solver
    end
    
    methods
        
        function this = flow_peltier(oMT, sName, fDeltaTemperature)
            
            this@matter.procs.f2f(oMT, sName);
            
            % Setting the initial temperature change
            this.fDeltaTemperature = fDeltaTemperature;
            
            % Setting the function handles and values to support the
            % different solvers
            this.supportSolver('manual', true, @this.update);
            this.supportSolver('callback', @this.solverDeltas);
            
        end
        
        % This function is called by the manual solver and just returns the
        % temperature difference set in this processor
        function fDeltaTemperature = update(this)
            fDeltaTemperature = this.fDeltaTemperature;
        end
        
        % This function is called by the manual solver and just returns the
        % temperature difference set in this processor as well as the
        % pressure drop, which is always zero.
        function [ fDeltaPressure, fDeltaTemperature ] = solverDeltas(this)
            fDeltaPressure    = 0;
            fDeltaTemperature = this.fDeltaTemperature;
        end
        
        % This function can be used to update the temperature difference
        % that this processor applies to the flow
        function setDeltaTemperature(this, fDeltaTemperature)
            this.fDeltaTemperature = fDeltaTemperature;
        end
        
    end
    
end

