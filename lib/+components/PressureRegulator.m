classdef PressureRegulator < vsys
    
    properties
        % Setting a fixed time step, otherwise everything would be WAY too
        % slow.
        fFixedTimeStep = 0.1;
        
        % A string that identifies the phase create helper to be used for
        % all phases in the regulator.
        sAtmosphereHelper = 'N2Atmosphere';
        
        bActive = false;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fPressureSetpoint = 28900; 
        
        tFirstStageParameters;
        tSecondStageParameters;
    end
    
    methods
        % constructor function
        function this = PressureRegulator(oParent, sName, tParameters)
            % call parent constructor
            this@vsys(oParent, sName);
            
            this.tFirstStageParameters  = tParameters.tFirstStageParameters;
            this.tSecondStageParameters = tParameters.tSecondStageParameters;
            
            if isfield(tParameters, 'fFixedTimeStep')
                this.fFixedTimeStep = tParameters.fFixedTimeStep;
            end
            
            if isfield(tParameters, 'bActive')
                this.bActive = tParameters.bActive;
            end
            
            if isfield(tParameters, 'sAtmosphereHelper')
                this.sAtmosphereHelper = tParameters.sAtmosphereHelper;
            end
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
          
            % add store interstage, volume 0.1 m^3, intermediate stage to
            % reduce the source oxygen pressure in two steps, the stage#1
            % valve is set to output 30bar + p_environment
            matter.store(this, 'InterStage', 0.01);
            % add phase to store interstage
            oGasPhaseInter = this.toStores.InterStage.createPhase(this.sAtmosphereHelper, 0.01, 293.15, 0, this.tFirstStageParameters.fPressureSetpoint);
            oGasPhaseInter.bSynced = true;
            
            % Adding Valves for the first and second stages
            components.PressureRegulator.valve(this, 'FirstStageValve', this.tFirstStageParameters); 
            components.PressureRegulator.valve(this, 'SecondStageValve', this.tSecondStageParameters); % 56500, [29600 42700 6270 56500 24800]);


            % add extract/merge processors
            matter.procs.exmes.gas(oGasPhaseInter, 'PortInterIn');
            matter.procs.exmes.gas(oGasPhaseInter, 'PortInterOut');
           
            % connect components to set flowpath
            matter.branch(this, 'InterStage.PortInterIn', {'FirstStageValve'}, 'Inlet', 'InletBranch');
            matter.branch(this, 'InterStage.PortInterOut', {'SecondStageValve'}, 'Outlet', 'OutletBranch');

        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % add branches to solver
            oBranch = solver.matter.linear.branch(this.toBranches.InletBranch);
            oBranch.fFixedTS = this.fFixedTimeStep;
            
            oBranch = solver.matter.linear.branch(this.toBranches.OutletBranch);
            oBranch.fFixedTS = this.fFixedTimeStep;
        end
        
        function setIfFlows(this, sInlet, sOutlet)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
            
        end
        
        function setEnvironmentReference(this, oGasPhaseEnvRef)
            this.toProcsF2F.FirstStageValve.setEnvironmentReference(oGasPhaseEnvRef);
            this.toProcsF2F.SecondStageValve.setEnvironmentReference(oGasPhaseEnvRef);
        end
        
        function setPressureSetpoint(this, fPressureSetpoint)
            this.fPressureSetpoint = fPressureSetpoint;
            
            % We are only changeing the setpoint of the second stage here,
            % the first stage should remain the same. 
            this.toProcsF2F.SecondStageValve.changeSetpoint(fPressureSetpoint);
            
        end
    end
    
    
    methods (Access = protected)
        function exec(this, ~)
            % call parent exec function
            exec@vsys(this);
        end
    end
end