classdef container < systems.root
    %CONTAINER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public)
        % Global timer object
        % @type object
        oTimer;
        
        % Global / unique matter table
        % @type object
        oMT;
        
        % Reference to the configuration object for vsystems (supporting
        % that feature, see simulation.configuration_parameters)
        % @type object
        oCfgParams;
        
        % Infrastructure Object for the simulation
        oInfrastructure;
        
        % Global solver tuning parameters
        % @type object
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
        function this = container(sName, oTimer, oMT, oCfgParams, tSolverParams, oInfra)
            this@systems.root(sName);
            
            this.oTimer     = oTimer;
            this.oMT        = oMT;
            this.oCfgParams = oCfgParams;
            this.oInfrastructure = oInfra;
            if nargin >= 5
                this.tSolverParams = tools.struct.mergeStructs(this.tSolverParams, tSolverParams);
            end
        end
        
        
        function this = addChild(this, oChild)
            addChild@systems.root(this, oChild);
            
            %oChild.createMatterStructure();
            %oChild.seal();
            %oChild.createSolverStructure();
        end
    end
    
end

