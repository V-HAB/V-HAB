classdef valve < matter.procs.f2f
    properties (SetAccess = public, GetAccess = public)
        % maximum outlet differential pressure
        fMaximumDeltaPressure = 56500;                  % [Pa]
        % valve cone opening angle 
        fThetaCone = 60;                                % [deg]
        % valve cone height
        fHeightCone = 0.05;                             % [m]
        % valve spring constant
        fCSpring = 22187;                               % [N/m]
        % valve opening at given pressure difference
        fXSetpoint = 0;                                 % [m]
        % Pressure setpoint for the valve
        fPressureSetpoint = 28300;                      % [Pa]
        % max opening for valve (physical border)
        fMaxValveOpening = 0.04                         % [m]
        % area of diaphragm at force equilibrium
        fAreaDiaphragm = 0.0079;                        % [m^2]
        % mass of diaphragm
        fMassDiaphragm = 0.01;                          % [kg]
        % simulation timestep value, get from branch
        fElapsedTime = 0;                                  % [s]
        % time at timestep n
        fTimeOld = 0;                                   % [s]
        % set time interval to change setpoint each x seconds
        fChangeSetpointInterval = 10;                   % [s]
        % index property for setpoint change
        iI = 1;                                         % [-]
        % is valve setpoint dynamically changeable?
        bChangeSetpoint = true;                         % [-]
        % the following properties are described for a state space system
        % of the form: E*x_n+1 = A*x_n + B*u
        % SSM, system state vector x at timestep n
        afSSM_VectorXOld = zeros(3, 1);
        % SSM, system state vector x at timestep n+1
        afSSM_VectorXNew = zeros(3, 1);
        % SSM, system entrance vector u
        afSSM_VectorU = zeros (3, 1);
        % SSM, matrix A
        mfSSM_MatrixA = zeros(3, 3);
        % SSM, matrix B
        mfSSM_MatrixB = zeros(3, 3);
        % SSM, matrix E
        mfSSM_MatrixE = zeros(3, 3);
        % Time constant for PT1 element
        fTPT1 = 0.02;                                    % [s]
        
        % Environment reference phase to get absolute pressure from
        oGasPhaseEnvRef;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % hydraulic diameter for solver
        fHydrDiam;
        
        % other solver parameters
        fHydrLength;
        fDeltaTemp = 0;
    end
    
    methods
        % valve constructor 
        function this = valve(oParent, sName, tParameters)
            this@matter.procs.f2f(oParent, sName);
            
            if isfield(tParameters, 'fMaximumDeltaPressure')
                % Initializing maximum outlet differential pressure.
                this.fMaximumDeltaPressure = tParameters.fMaximumDeltaPressure;
            end
            
            if isfield(tParameters, 'fPressureSetpoint')
                this.fPressureSetpoint = tParameters.fPressureSetpoint;
            end
            
            if isfield(tParameters, 'fThetaCone') 
                this.fThetaCone = tParameters.fThetaCone;
            end
            
            if isfield(tParameters, 'fHeightCone') 
                this.fHeightCone = tParameters.fHeightCone;
            end
            
            if isfield(tParameters, 'fCSpring')
                this.fCSpring = tParameters.fCSpring;
            end
            
            if isfield(tParameters, 'fMaxValveOpening')
                this.fMaxValveOpening = tParameters.fMaxValveOpening;
            end
            
            if isfield(tParameters, 'fAreaDiaphragm')
                this.fAreaDiaphragm = tParameters.fAreaDiaphragm;
            end
            
            if isfield(tParameters, 'fMassDiaphragm')
                this.fMassDiaphragm = tParameters.fMassDiaphragm;
            end
            
            if isfield(tParameters, 'fTPT1')
                this.fTPT1 = tParameters.fTPT1;
            end
            
            % initialise fXSetpoint, if first vector entry above maximum,
            % fXSetpoint will stay at initial zero
            if this.fPressureSetpoint <= this.fMaximumDeltaPressure
                this.fXSetpoint = (this.fPressureSetpoint * this.fAreaDiaphragm) / this.fCSpring;
            end
            
            % initialise values for state space system
            this.mfSSM_MatrixA(1, :) = [1 0 0];
            this.mfSSM_MatrixA(2, :) = [0 1 0];
            this.mfSSM_MatrixE(1, 1) = 1;
            this.mfSSM_MatrixE(2, 2) = 1;
            this.mfSSM_MatrixE(3, 3) = 1;
            
            % initialize hydraulic values             
            this.fHydrDiam = 0.0001;
            
            % set hydraulic length
            this.fHydrLength = this.fHeightCone / cos(deg2rad(this.fThetaCone / 2));
            
            this.supportSolver('hydraulic', this.fHydrDiam, this.fHydrLength, true, @this.update);
        end
        
        function setEnvironmentReference(this, oGasPhaseEnvRef)
            this.oGasPhaseEnvRef = oGasPhaseEnvRef;
            
        end

        % function for valve dislocation, implicit
        function DeltaX(this, fPressureChamber)
            % set variables of system entrance
            fPressureReference = this.oGasPhaseEnvRef.fMass * this.oGasPhaseEnvRef.fMassToPressure;
            this.afSSM_VectorU = [fPressureReference; fPressureChamber; this.fXSetpoint];
            
            % set the missing matrix values
            this.mfSSM_MatrixA(3, 3) = this.fTPT1 / (this.fTPT1 + this.fElapsedTime);
            
            this.mfSSM_MatrixB(2, :) = [(this.fAreaDiaphragm * this.fElapsedTime) / this.fMassDiaphragm; ...
                                       -(this.fAreaDiaphragm * this.fElapsedTime) / this.fMassDiaphragm; ...
                                       (this.fCSpring * this.fElapsedTime) / this.fMassDiaphragm];
            
            this.mfSSM_MatrixE(2, 1) = (this.fCSpring * this.fElapsedTime) / this.fMassDiaphragm;
            this.mfSSM_MatrixE(1, 2) = -this.fElapsedTime;
            this.mfSSM_MatrixE(3, 1) = -(1 / ((this.fTPT1 / this.fElapsedTime) + 1));
            
            % solve implicit linear equation system E*x_n+1 = A*x_n + B*u
            this.afSSM_VectorXNew = this.mfSSM_MatrixE \ (this.mfSSM_MatrixA * this.afSSM_VectorXOld + this.mfSSM_MatrixB * this.afSSM_VectorU);
            
            % valve is closed at x = 0, physical barrier
            if this.afSSM_VectorXNew(3) < 0
                this.afSSM_VectorXNew(3) = 0;
            end
            
            % valve cannot open farther than specified value, another
            % physical barrier
            if this.afSSM_VectorXNew(3) > this.fMaxValveOpening
                this.afSSM_VectorXNew(3) = this.fMaxValveOpening;
            end
            
            % no negative speed possible when valve is already closed
            if this.afSSM_VectorXNew(3) == 0 && this.afSSM_VectorXNew(2) < 0
                this.afSSM_VectorXNew(2) = 0;
            end
            
            % delayed value gets real
            this.afSSM_VectorXNew(1) = this.afSSM_VectorXNew(3);
            % set "old" values for new runthrough
            this.afSSM_VectorXOld = this.afSSM_VectorXNew;  
        end
        
        % function for calculating the hydraulic diameter
        function HydrDiam(this)
            % calculate distance between valve cones
            fDistanceCones = this.afSSM_VectorXNew(3) * sin(deg2rad(this.fThetaCone / 2));
            % cones touch each other at distance 0, prevent negative values
            if fDistanceCones < 0
                fDistanceCones = 0;
            end
            
            % calculate hydraulic diameter ((4 * A) / U)
            this.fHydrDiam = 2 * fDistanceCones;
            % cannot be negative
            if this.fHydrDiam < 0
                this.fHydrDiam = 0;
            end
        end
        
        %% update parameters       
        function update(this)
            
            % If the regulator associated with this valve is inactive, we
            % just set the hydraulic diameter to zero and return.
            if this.oContainer.bActive == false
                this.fHydrDiam = 0;
                this.toSolve.hydraulic.fHydrDiam = this.fHydrDiam;
                
                % Save current time value for new timestep calculation when
                % the actual update is next executed. This prevents a large
                % transient at that point. 
                this.fTimeOld = this.oBranch.oContainer.oTimer.fTime;
                
                return;
            end
            % Get timestep of simualtion
            this.fElapsedTime = (this.oBranch.oContainer.oTimer.fTime - this.fTimeOld);
            
            if this.fElapsedTime <= 0
                return;
            end
            
            % Calculate valve dislocation
            oPhaseLeft = this.oBranch.coExmes{1}.oPhase;
            fChamberPressureLeft = oPhaseLeft.fMass * oPhaseLeft.fMassToPressure;
            oPhaseRight = this.oBranch.coExmes{2}.oPhase;
            fChamberPressureRight = oPhaseRight.fMass * oPhaseRight.fMassToPressure;
            if fChamberPressureLeft > fChamberPressureRight
                fChamberPressure = fChamberPressureRight;
            else
                fChamberPressure = fChamberPressureLeft;
            end
            this.DeltaX(fChamberPressure);
            % Calculate hydraulic diameter
            this.HydrDiam();
            % Save current time value for new timestep calculation
            this.fTimeOld = this.oBranch.oContainer.oTimer.fTime;
            
            % Setting the new hydraulic diameter on the solver properties
            % object.
            this.toSolve.hydraulic.fHydrDiam = this.fHydrDiam;
        end
    end 
    
    methods (Access = public)
        % change setpoint of the valve
        function changeSetpoint(this, fPressureSetpoint)
            this.fPressureSetpoint = fPressureSetpoint;
            this.fXSetpoint = (fPressureSetpoint * this.fAreaDiaphragm) / this.fCSpring;
        end
    end
end