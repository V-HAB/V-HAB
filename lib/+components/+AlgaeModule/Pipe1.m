%classdef Pipe < solver.basic.matter.procs.f2f & solver.matter.linear.procs.f2f
classdef Pipe1 < matter.procs.f2f
    %PIPE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant = true)
        % For reynolds number calculation
        C = struct(...
            'fEta', 17.2, ...   % [10^6 Pa s]
            'Re_c', 2040 ...   % [10^6 Pa s]
        );
    end
    
    properties (SetAccess = public, GetAccess = public)
        % Length, diameter in [m]
        fLength   = 0;
        fDiameter = 0;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam;
        fHydrLength;
        bActive = false;
        fDeltaTemp = 0;
        fDeltaPress = 0;
    end
    
    methods
        function  this = Pipe1(oMT, sName, fLength, fDiameter)
            %this@solver.basic.matter.procs.f2f(oMT, sName);
            this@matter.procs.f2f(oMT, sName);
            %this@matter.procs.f2f(oMT, sName);
            
            this.fLength   = fLength;
            this.fDiameter = fDiameter;
            
            % Linear solver
            this.fHydrDiam   = fDiameter;
            this.fHydrLength = fLength;
        end
        
        function [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, fFlowRate)
            fDeltaTemp  = 0;
            
            if (fFlowRate == 0)
                fDeltaPress = 0;
                return;
            end
            
            % Get in/out flow object references
            [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);
            
            % Average pressure
            fP = (oFlowIn.fPressure + oFlowOut.fPressure) / 2;
            
            % No pressure at all ... normally just return, drop zero
            if fP == 0
                fDeltaPress = 0;
                return;
            end
            
            
            % Calculate density and flow speed
            %TODO do with matter.table
            fRoh = (fP * oFlowIn.fMolarMass) / (matter.table.Const.fUniversalGas * oFlowIn.fTemperature);
            fV   = abs(fFlowRate) / ((pi / 4) * this.fDiameter^2 * fRoh);

            % Reynolds
            Re     = fV * this.fDiameter * fRoh / (this.C.fEta / 10^6);
            lambda = 0;
            
            %disp(num2str(Re));
            
            % Interpolate transition between turbulent and laminar
            pInterp = 0.1;
            
            % (PDF) Laminar: Hagen-Poiseuille
            if Re <= this.C.Re_c * (1 - pInterp)
                lambda = 64 / Re;
                %disp('lam');

            % Interpolation between laminar and turbulent
            elseif (this.C.Re_c * (1 - pInterp) < Re) && (Re <= this.C.Re_c * (1 + pInterp))
                lambda_lam  = 64 / Re;
                lambda_turb = 0.3164 / Re^(1/4);

                pInterp = (-this.C.Re_c * (1 - pInterp) + Re) / (this.C.Re_c * 2 * pInterp);
                %keyboard();
                lambda = lambda_lam + (lambda_turb - lambda_lam) * pInterp;
                
                %disp('intp');
            
            
            %CHECK EQUATIONS friction factor! DROP at blas>prandtl
            %   http://www.brighthubengineering.com/hydraulics-civil-engineering/55227-pipe-flow-calculations-3-the-friction-factor-and-frictional-head-loss/
            %   http://www.efunda.com/formulae/fluids/calc_pipe_friction.cfm#friction
            %   http://eprints.iisc.ernet.in/9587/1/Friction_Factor_for_Turbulent_Pipe_Flow.pdf
            % HERE: all smooth, just blasius?
            
            %(PDF) Turbulent: Blasius
            elseif (this.C.Re_c * (1 + pInterp) < Re) && (Re <= 10^5)
                lambda = 0.3164 / Re^(1/4);
                %lambda = 1 / (1.8 * log(Re / 7))^2;
                
                %disp('turb_blas');

            % (PPT) Turbulent: Prantl
            elseif (10^5 < Re) && (Re < 10^8)
                %ISSUE using the Blasius (smooth) flow equation - Prandtl
                %      actually produced LOWER lambdas --> WAAAY to high
                %      flow rates!!
                lambda = 0.3164 / Re^(1/4);
                %lambda = 1 / (1.8 * log(Re / 7))^2;
                
                %disp('turb_pra');
                
            else
                this.warn('solverDeltas', [ 'Reynolds ' num2str(Re) ' not covered!' ]);
                
                % Just assume prantl * 2
                lambda = 1 / (1.8 * log(Re / 7))^2 * 10;
                
                %if isnan(Re), keyboard(); end;
            end
            
            fDeltaPress = fRoh / 2 * fV^2 * (lambda * this.fLength / this.fDiameter);
            
            
            %disp([ 'Speed ' num2str(fV) ', Re ' num2str(Re) ', P ' num2str(fP) ', Roh ' num2str(fRoh) ', DeltaP ' num2str(fDeltaPress) ', FR ' num2str(fFlowRate) ', lambda ' num2str(lambda) ]);
            
            %TODO check V2 (output speed -> pressure at output + FR) ==> if
            %     CHOKED (>= speed of sound) -> increase deltaP accordingly
            
            %disp([ this.sName ' drop is ' num2str(fDeltaPress) ' Pa' ]);
        end
    end
    
end
