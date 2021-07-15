classdef PPRV < matter.procs.f2f
    
    properties (SetAccess = public, GetAccess = public)
        % max pressure difference allowed for PPRV,
        % if chamber pressure higher -> open 
        fDeltaPressureMaxValve = 60000;                 % [Pa]
        % valve cone opening angle 
        fThetaCone = 60;                                % [deg]
        % valve cone height
        fHeightCone = 0.05;                             % [m]
        % valve spring constant
        fCSpring = 23700;                               % [N/m]
        % spring force on still closed valve at fMaxDeltaPressurePPRV,
        % will start to open if pressure > fMaxDeltaPressurePPRV.
        % is directly connected to fMaxDeltaPressurePPRV like fXSetpoint in
        % the other valves. describes a linear shift of the spring force:
        % SpringForce = fSpringCoeff + fCSpring*DeltaX
        fSpringCoeff = 474;                             % [N]
        % valve opening at given pressure difference, required by abstract
        % superclass but not needed here as the valve is always closed at
        % the given pressure difference fMaxDeltaPressurePPRV. fSpringCoeff
        % takes the place here
        fXSetpoint = 0;                                 % [m]
        % max opening for valve (physical border)
        fMaxValveOpening = 0.04                         % [m]
        % area of sensing diaphragm 
        fAreaDiaphragm = 0.0079;                        % [m^2]
        % mass of sensing diaphragm
        fMassDiaphragm = 0.01;                          % [kg]
        % simulation timestep value, get from branch
        fTimeStep = 0;                                  % [s]
        % time at timestep n
        fTimeOld = 0;                                   % [s]
        % the following properties are described for a state space system
        % of the form: E*x_n+1 = A*x_n + B*u
        % SSM, system state vector x at timestep n
        afSSM_VectorXOld = zeros(2, 1);
        % SSM, system state vector x at timestep n+1
        afSSM_VectorXNew = zeros(2, 1);
        % SSM, system entrance vector u
        afSSM_VectorU = zeros(3, 1);
        % SSM, matrix A
        mfSSM_MatrixA = zeros(2, 2);
        % SSM, matrix B
        mfSSM_MatrixB = zeros(2, 3);
        % SSM, matrix E
        mfSSM_MatrixE = zeros(2, 2);
        
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
        function this = PPRV(oParent, sName, fDeltaPressureMaxValve, fThetaCone, fHeightCone, fCSpring, fXSetpoint, fMaxValveOpening, fAreaDiaphragm, fMassDiaphragm, fTPT1, bChangeSetpoint)
            this@matter.procs.f2f(oParent, sName);
            
            % initialise critical pressure, valve will open if exceeded
            this.fDeltaPressureMaxValve = fDeltaPressureMaxValve;
            
            % check for more than 2 input arguments
            if nargin > 3
                % initialise other values
                this.fThetaCone = fThetaCone;
                this.fHeightCone = fHeightCone;
                this.fCSpring = fCSpring;
                this.fXSetpoint = fXSetpoint;
                this.fMaxValveOpening = fMaxValveOpening;
                this.fAreaDiaphragm = fAreaDiaphragm;
                this.fMassDiaphragm = fMassDiaphragm;
                this.fTPT1 = fTPT1;
                this.bChangeSetpoint = bChangeSetpoint;
            end
            
            this.bActive = true;
            
            % calculate spring force to keep valve closed until at pressure 
            % fDeltaPressureMaxValve
            this.fSpringCoeff = this.fDeltaPressureMaxValve * this.fAreaDiaphragm;
    
            % initialise values for state space system
            this.mfSSM_MatrixA(1, :) = [1 0];
            this.mfSSM_MatrixA(2, :) = [0 -1];
            this.mfSSM_MatrixE(1, 1) = 1;
            this.mfSSM_MatrixE(2, 2) = 1;
            
            % initialize hydraulic values 
            this.fHydrDiam = 0;

            % set hydraulic length
            this.fHydrLength = this.fHeightCone / cos(deg2rad(this.fThetaCone / 2));
            
            this.supportSolver('hydraulic', this.fHydrDiam, this.fHydrLength, true, @this.update);
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        function setEnvironmentReference(this, oGasPhaseEnvRef)
            this.oGasPhaseEnvRef = oGasPhaseEnvRef;
            
        end

        % function for valve dislocation, implicit
        function DeltaX(this, fPressureChamber)
                % set variables of system entrance
                fPressureReference = this.oGasPhaseEnvRef.fMass * this.oGasPhaseEnvRef.fMassToPressure;
                this.afSSM_VectorU = [fPressureChamber; fPressureReference; this.fSpringCoeff];
            
                % set the missing matrix values
                this.mfSSM_MatrixB(2, :) = [(this.fAreaDiaphragm * this.fTimeStep) / this.fMassDiaphragm; ...
                                            -(this.fAreaDiaphragm * this.fTimeStep) / this.fMassDiaphragm; ...
                                            -this.fTimeStep / this.fMassDiaphragm];
            
                this.mfSSM_MatrixE(2, 1) = (this.fCSpring * this.fTimeStep) / this.fMassDiaphragm;
                this.mfSSM_MatrixE(1, 2) = -this.fTimeStep;
                
                % solve implicit linear equation system E*x_n+1 = A*x_n + B*u
                this.afSSM_VectorXNew = this.mfSSM_MatrixE \ (this.mfSSM_MatrixA * this.afSSM_VectorXOld + this.mfSSM_MatrixB * this.afSSM_VectorU);
            
                % valve is closed at x = 0, physical barrier
                if this.afSSM_VectorXNew(1) < 0
                    this.afSSM_VectorXNew(1) = 0;
                end
            
                % valve cannot open farther than specified value, another
                % physical barrier
                if this.afSSM_VectorXNew(1) > this.fMaxValveOpening
                    this.afSSM_VectorXNew(1) = this.fMaxValveOpening;
                end
            
                % no negative speed possible when valve is already closed
                if this.afSSM_VectorXNew(1) == 0 && this.afSSM_VectorXNew(2) < 0
                    this.afSSM_VectorXNew(2) = 0;
                end

                % set "old" values for new runthrough
                this.afSSM_VectorXOld = this.afSSM_VectorXNew;  
        end
        
        % function for calculating the hydraulic diameter
        function HydrDiam(this)
            % calculate hydraulic diameter ((4 * A) / U), disc valve
            this.fHydrDiam = 2 * this.afSSM_VectorXNew(1);
            % cannot be negative
            if this.fHydrDiam < 0
                this.fHydrDiam = 0;
            end
        end
        
        %% update parameters    
        function update(this)
            % get timestep of simualtion
            this.fTimeStep = (this.oBranch.oContainer.oTimer.fTime - this.fTimeOld);
            % calculate valve dislocation
            oPhase = this.oBranch.coExmes{1}.oPhase;
            fChamberPressure = oPhase.fMass * oPhase.fMassToPressure;
            this.DeltaX(fChamberPressure);
            % calculate hydraulic diameter
            this.HydrDiam();
            % save current time value for new timestep calculation
            this.fTimeOld = this.oBranch.oContainer.oTimer.fTime;
            
            % check valve dislocation, if greater than specified value,
            % increase diaphragm area (to simulate the area increase effect
            % in pressure relief valves to rapidly open to max lift)
            if this.afSSM_VectorXNew(1) > this.fMaxValveOpening * 0.01
                this.fMassDiaphragm = 0.0079 * 2;
            else
                this.fMassDiaphragm = 0.0079;
            end
            
            this.toSolve.hydraulic.fHydrDiam = this.fHydrDiam;
        end
        
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            
            this.update();
            fCoeff = this.fHydrDiam * 0.00000133 * 20 ./ this.fHydrLength;
            
            oPhaseLeft = this.oBranch.coExmes{1}.oPhase;
            fChamberPressureLeft = oPhaseLeft.fMass * oPhaseLeft.fMassToPressure;
            oPhaseRight = this.oBranch.coExmes{2}.oPhase;
            fChamberPressureRight = oPhaseRight.fMass * oPhaseRight.fMassToPressure;
            
            fTargetFlowRate = fCoeff * (fChamberPressureLeft - fChamberPressureRight);
            
            % if the flowrate is too small, reduce the pressure drop to
            % allow higher flowrates. If it is too large increase the
            % pressure drop to enforce lower flowrates
            fDeltaPressure = (fFlowRate / fTargetFlowRate) * (fChamberPressureLeft - fChamberPressureRight);
            
        end
    end
end