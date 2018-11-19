classdef def < vsys
    %EXAMPLE Example simulation for a fan driven gas flow in V-HAB 2.0
    %   Two tanks, filled with gas at different pressures, a fan in between
    %   and two pipes to connect it all
    
    properties
        oSolver;
        oHeater;
    end
    
    methods
        function this = def(oParent, sName, sDirection, sSolver, sAdditionalComps)
            this@vsys(oParent, sName, 50);
            
            if nargin < 3 || isempty(sDirection), sDirection = 'left_to_right'; end
            if nargin < 4 || isempty(sSolver),    sSolver    = 'iterative'; end
            if nargin < 5, sAdditionalComps = ''; end
            
            if strcmp(sDirection, 'left_to_right') 
                iPhaseLeftPressureInc  = 2;
                iPhaseRightPressureInc = 1;
            else
                iPhaseLeftPressureInc = 1;
                iPhaseRightPressureInc = 2;
            end
            
            %TODO
            % - param -- which solver (manual, iterative, linear)
            % - oSolver, oHeater --> refs to solver, f2f - access from ext
            % - plot all f2fs / flows in branch!
            
            
            %%%% STORES %%%%
            
            this.addStore(matter.store(this.oData.oMT, 'Tank_Left',  10));
            this.addStore(matter.store(this.oData.oMT, 'Tank_Right', 10));
            
            aoPhases = matter.phases.gas.empty(2, 0);
            aoPhases(1) = this.toStores.Tank_Left.createPhase ('air', 10 * iPhaseLeftPressureInc);
            aoPhases(2) = this.toStores.Tank_Right.createPhase('air', 10 * iPhaseRightPressureInc);
            
            matter.procs.exmes.gas(aoPhases(1), 'Port');
            matter.procs.exmes.gas(aoPhases(2), 'Port');
            
            
            
            %%%% COMPS %%%%
            fPipeDiam = 0.0015;
            
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_1', 1, fPipeDiam));
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_2', 1, fPipeDiam));
            
            csFlowProcs = { 'Pipe_1', 'Pipe_2' };
            
            
            if strcmp(sAdditionalComps, 'heater') || strcmp(sAdditionalComps, 'heater_and_pipes')
                this.oHeater = components.matter.heater(this.oData.oMT, 'Heater');
                
                this.addProcF2F(this.oHeater);
                
                csFlowProcs{end + 1} = 'Heater';
            end
            
            if strcmp(sAdditionalComps, 'pipes') || strcmp(sAdditionalComps, 'heater_and_pipes')
                this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_3', 1, fPipeDiam));
                this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_4', 1, fPipeDiam));
                
                csFlowProcs{end + 1} = 'Pipe_3';
                csFlowProcs{end + 1} = 'Pipe_4';
            end
            
            %TODO as soon as new logging logic implemented, add comps and
            %     additional comps (if active) to logging
            
            
            %%%% BRANCHES %%%%
            
            this.createBranch('Tank_Left.Port', csFlowProcs, 'Tank_Right.Port');
            
            
            
            
            
            this.seal(); %%%% SEAL %%%%
            
            %%%% SOLVERS %%%%
            this.oSolver = solver.matter.(sSolver).branch(this.aoBranches(1));
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            
            if ~isempty(this.oHeater)
                fTime  = this.oTimer.fTime;
                fPower = this.oHeater.fPower;
                
                
                if fTime > 3200 && fPower ~= 0
                    this.oHeater.setPower(0);
                    disp('FINAL - Setting heater power to 0W');
                    
                elseif fTime > 3100 && fTime < 3200 && fPower ~= 50
                    this.oHeater.setPower(50);
                    disp('SHORT - Setting heater power to 50W');
                    
                    
                elseif fTime > 2500 && fTime < 3500 && fPower ~= 0
                    this.oHeater.setPower(0);
                    disp('Setting heater power to 0W');
                    
                elseif fTime >= 1500 && fTime < 2500 && fPower ~= 20
                    this.oHeater.setPower(20);
                    disp('Setting heater power to 20W');
                    
                elseif fTime >= 500 && fTime < 1500 && fPower ~= 10
                    this.oHeater.setPower(10);
                    disp('Setting heater power to 10W');
                    
                end
            end
        end
        
     end
    
end

