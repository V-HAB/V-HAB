classdef container < systems.root
    %CONTAINER Summary this is the basic container class which provides the
    % general framework for all types (matter, thermal, electrical...) of
    % containers that make up the vsys in the final simulation. It provides
    % the generally necessary properties and methods for all the child
    % classes, which then implement the more specific methods and
    % properties. The vsys is then a combination of the inidivdual
    % containers
    
    properties (SetAccess = private, GetAccess = public)
        % Global timer object
        oTimer;
        
        % Global / unique matter table
        oMT;
        
        % Reference to the configuration object for vsystems (supporting
        % that feature, see simulation.configuration_parameters)
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
            this@systems.root(sName);
            
            this.oTimer     = oTimer;
            this.oMT        = oMT;
            this.oCfgParams = oCfgParams;
            
            if nargin >= 5
                this.tSolverParams = tools.struct.mergeStructs(this.tSolverParams, tSolverParams);
            end
        end
        
        
        function this = addChild(this, oChild)
            addChild@systems.root(this, oChild);
        end
    end
end

