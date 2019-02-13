classdef container < systems.root
    %CONTAINER Base class for simulation models
    % This is the basic container class which provides the general
    % framework for models to be created in V-HAB. It is the root system
    % for each simulation. 
    
    % Since this is such a basic class, all of its properties have private
    % SetAccess. 
    properties (SetAccess = private, GetAccess = public)
        % Global timer object
        oTimer;
        
        % Global / unique matter table
        oMT;
        
        % Reference to the configuration object for vsys. For more
        % information on that feature, see
        % simulation.configurationParameters.
        oCfgParams;
        
        % Global solver tuning parameters
        tSolverParams = struct(...
            ... % Used to adjust the rMaxChange parameter in (gas) phases. Can
            ... % still be set manually (after .seal() was called). Sets the
            ... % rMaxChange value according to the volume multiplied by this
            ... % parameter here.
            'rUpdateFrequency', 1, ...
            ...
            ... % Adaptive rMaxChange- if phase mass does not change, value is
            ... % decreased accordingly
            'rHighestMaxChangeDecrease', 0, ...
            ...
            ... %  For each (iterative) solver, a dampening value can be set in
            ... %  the constructor which is multiplied with this value
            ... 'rSolverDampening', 1, ...
            ...
            ... %  Max time step for phases, solvers, ...
            'fMaxTimeStep', 20, ...
            ...
            ... % Sensitivity of the solvers towards changes (atm just iterative)
            'fSolverSensitivity', 5 ...
        );
    end
    
    methods
        function this = container(sName, oTimer, oMT, oCfgParams, tSolverParams)
            % Calling the parent constructor
            this@systems.root(sName);
            
            % Setting the object properties according to the input
            % arguments
            this.oTimer     = oTimer;
            this.oMT        = oMT;
            this.oCfgParams = oCfgParams;
            
            % Setting the solver parameters, if they were provided. 
            if nargin >= 5
                this.tSolverParams = tools.struct.mergeStructs(this.tSolverParams, tSolverParams);
            end
        end
    end
end

