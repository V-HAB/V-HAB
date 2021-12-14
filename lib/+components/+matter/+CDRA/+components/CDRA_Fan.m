classdef CDRA_Fan < matter.procs.f2f
    %FAN_SIMPLE Linear, static, RPM dependent fan model
    %   Interpolates between max flow rate and max pressure rise, values
    %   taken from the Calnetix fan.
    
    % Calnetix Technologies designed and developed a high-speed in-line 
    % blower and a dual controller for NASA’s next-generation CO2 removal 
    % system, the Four Bed Carbon Dioxide Scrubber (4BCO2).
    
    % Calnetix was responsible for the development of the blower assembly, 
    % which includes a compact in-line blower on magnetic bearings, called 
    % Momentum™, and an integrated hybrid dual controller, called 
    % Continuum™, to drive the blower. The magnetically levitated in-line 
    % blower is an integral component of the CO2 removal system and will 
    % drive the airflow through the entire system in a microgravity space 
    % environment. 

    % Calnetix’s Momentum™ In-line Blower features an overhung permanent 
    % magnet motor, a centrally located five-axis active magnetic bearing 
    % (AMB) system, backup bearings and an overhung centrifugal impeller in 
    % a very compact package. Magnetic bearings were used instead of 
    % conventional bearings due to their low transmitted vibration, high-
    % speed levitation, low power consumption, high reliability, oil-free 
    % operation and tolerance to particle contaminants in the air stream. 
    % https://www.calnetix.com/newsroom/press-release/calnetix-technologies-supplies-key-components-nasas-next-generation-co2
    
    properties
        fVolumetricAirFlow = 0.02;  % Setpoint for the CDRA fan flow [m^3/s]
        iDir = 1;            % Direction of flow
        
        % Parameter to check if the fan is on or off
        bTurnedOn = true;
        fFanSpeed = 0; % [rpm]
    end
        
    methods
        function this = CDRA_Fan(oParent, sName, fVolumetricAirFlow, bReverse) 
        % Is the above function statement correct?  Or should it be the
        % statement on the line below?  
        %function this = fan_simple(oParent, sName, fMaxDeltaP, bReverse)
            this@matter.procs.f2f(oParent, sName);
            
            % tells solvers that this component produces a pressure rise
            this.bActive = true;
            
            if nargin >= 3
                this.fVolumetricAirFlow = fVolumetricAirFlow;
            end
            
            if (nargin >= 4) && islogical(bReverse) && bReverse
                this.iDir = -1;
            end
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function switchOn(this)
            this.bTurnedOn = true;
            this.oBranch.setOutdated();
        end
        
        function switchOff(this)
            this.bTurnedOn = false;
            this.oBranch.setOutdated();
        end
        
        function setVolumetricFlowRate(this, fVolumetricAirFlow)
            this.fVolumetricAirFlow = fVolumetricAirFlow;
            this.oBranch.setOutdated();
        end
        
        function [ fDeltaPressure, fDeltaTemp ] = solverDeltas(this, ~)
            % The calculation is independent of the actual flowrate as we
            % assume just a constant delta pressure from the fan
            
            if this.bTurnedOn
                fDeltaTemp = 0;
                
                % Calculate the delta P from curve fit to the fan performance
                % Correct for the ratio of actual density to the reference
                % density assuming 100 kPa and 15C? TBD
                % Note pressure rises are assumed to be negative values in
                % V-HAB!
                fDeltaPressure = -1 * 59.60E+06 * this.fVolumetricAirFlow^2; % [Pa]
                this.fDeltaPressure = fDeltaPressure;
                % Calculate the fan speed based on commanded flow.  Do not
                % update if the air flow rate falls due to increased back pressure.
                this.fFanSpeed = 4.382E+06*this.fVolumetricAirFlow; % [rpm]
            else
                this.fDeltaPressure = 0;
                fDeltaPressure = 0;
            end
        end
        
        function fDeltaTemperature = updateManualSolver(this)
            fDeltaTemperature = this.fDeltaTemperature;
            
        end
    end
    
end

