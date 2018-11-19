classdef Example_Multiple < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1.0;
        fPipeDiameter = 0.0035;
        
        
        % Store volumes in m3
        afStoreVolumes = [ 1000 0.0005 0.0005 0.0005 0.0005 0.0005 0.0005 1000 ];
        
        % For air helper - create air for how much volume (multiple of
        % fVolume)
        arPressures = [ 3 1 1 1 1 1 1 1 ];
        
        
        
        % Connect which stores with branches?
        aaiBranches = [
            1, 2;
            
            2, 3;
            2, 4;
            
            
            3, 5;
            3, 6;
            
            4, 5;
            4, 6;
            
            5, 7;
            6, 7;
            
            7, 8;
            
            
            % ALSO --> include value for pipe lenght optionally!
        ];
    
    
        %{
        
                /-> T3
        S1 -> T2
                \-> T4
        
        
        
        T1 -> T2

        T2 -> 1 -> T3
        T2 -> 1 -> T4
        T3 -> 1 -> T5
        T3 -> 1 -> T6
        T4 -> 1 -> T5
        T4 -> 1 -> T6
        T5 -> 1 -> T7
        T6 -> 1 -> T7

        T7 -> T8

        
        %}
        
        
        piPipeLengths;
    end
    
    methods
        function this = Example_Multiple(oParent, sName)
            this@vsys(oParent, sName, 100);
            
            
            this.piPipeLengths = containers.Map();
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            % Create three stores with three phases each. Also create
            % exmes, if several - append number!
            iStoresTotal = length(this.afStoreVolumes);
            
            for iS = 1:iStoresTotal
                sS = sprintf('Tank_%i', iS);
                
                matter.store(this, sS, this.afStoreVolumes(iS));
                
                this.toStores.(sS).createPhase('air', this.arPressures(iS) * this.toStores.(sS).fVolume);
                
                this.toStores.(sS).aoPhases(1).bSynced = true;
                
                %matter.procs.exmes.gas(this.toStores.(sS).aoPhases(1), sprintf('Port_%i', iE));
            end
            
            
            % Create branches with pipes and valves
            for iB = 1:size(this.aaiBranches, 1)
                iStoreLeft  = this.aaiBranches(iB, 1);
                iStoreRight = this.aaiBranches(iB, 2);
                fPipeLen    = this.fPipeLength;
                
                if this.piPipeLengths.isKey(iB)
                    fPipeLen = this.piPipeLengths(iB);
                end
                
                csFlowProcs = {
                    components.matter.pipe(this, sprintf('Pipe_%i%i', iStoreLeft, iStoreRight), fPipeLen, this.fPipeDiameter).sName;
                };
                
                sLeftStore  = sprintf('Tank_%i', iStoreLeft);
                sRightStore = sprintf('Tank_%i', iStoreRight);
                
                
                % Create Exmes
                iExmeLeft  = length(fieldnames(this.toStores.(sLeftStore ).aoPhases(1).toProcsEXME)) + 1;
                iExmeRight = length(fieldnames(this.toStores.(sRightStore).aoPhases(1).toProcsEXME)) + 1;
                
                matter.procs.exmes.gas(this.toStores.(sLeftStore ).aoPhases(1), sprintf('Port_%i', iExmeLeft));
                matter.procs.exmes.gas(this.toStores.(sRightStore).aoPhases(1), sprintf('Port_%i', iExmeRight));
                
                
                
                matter.branch(this, ...
                    sprintf('Tank_%i.Port_%i', iStoreLeft, iExmeLeft), ...
                    csFlowProcs, ...
                    sprintf('Tank_%i.Port_%i', iStoreRight, iExmeRight));
            end
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            for iB = 1:length(this.aoBranches)
                solver.matter.iterative.branch(this.aoBranches(iB));
            end
            
            this.setThermalSolvers();
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            
            
            return;
            
            % Compare to fStartTime - this.fTimeStep -> .exec might get
            % executed slightly earlier than defined through time step.
            
            % Open/Close valves
            if this.oTimer.fTime > (7200 - this.fTimeStep) && this.oTimer.fTime < 9000
                if this.fTimeStep ~= 1
                    this.setTimeStep(50);
                end
                
                if ~this.toProcsF2F.Valve_12.bOpen && ~this.toProcsF2F.Valve_23.bOpen
                    this.toProcsF2F.Valve_12.setOpened();
                    
                elseif this.toProcsF2F.Valve_12.bOpen && ~this.toProcsF2F.Valve_23.bOpen
                    this.toProcsF2F.Valve_23.setOpened();
                    
                elseif ~this.toProcsF2F.Valve_12.bOpen && this.toProcsF2F.Valve_23.bOpen
                    this.toProcsF2F.Valve_23.setClosed();
                    
                else % both open
                    this.toProcsF2F.Valve_12.setClosed();
                    
                end
                
            
            % Emulate Cvs
            elseif this.oTimer.fTime > (1800 - this.fTimeStep) && this.oTimer.fTime < 5400
                if this.fTimeStep ~= 5
                    this.setTimeStep(5);
                else
                    
                    % -1800 to + 1800
                    fRange = this.oTimer.fTime - 1800 - 1800; % Time minus start time minus half of duration
                    rInc   = abs(fRange / 1800); % 1 -> 0 -> 1
                    
                    this.toProcsF2F.Valve_12.setFlowCoefficient(this.afFlowCoeffs(1) * min([ 1 / rInc, 1000 ]));
                    this.toProcsF2F.Valve_23.setFlowCoefficient(this.afFlowCoeffs(2) * rInc);
                    
                    if mod(this.oTimer.iTick, 10) == 0
                        %fprintf('[%i] %f / %f\n', this.oTimer.iTick, this.toProcsF2F.Valve_12.fFlowCoefficient, this.toProcsF2F.Valve_23.fFlowCoefficient)
                    end
                end
                
            % SOmething to reset?
            else
                if this.fTimeStep ~= 100
                    this.setTimeStep(100);
                end
                
                
                if ~this.toProcsF2F.Valve_12.bOpen, this.toProcsF2F.Valve_12.setOpened(); end;
                if ~this.toProcsF2F.Valve_23.bOpen, this.toProcsF2F.Valve_23.setOpened(); end;
                
                if this.toProcsF2F.Valve_12.fFlowCoefficient ~= this.afFlowCoeffs(1), this.toProcsF2F.Valve_12.setFlowCoefficient(this.afFlowCoeffs(1)); end;
                if this.toProcsF2F.Valve_23.fFlowCoefficient ~= this.afFlowCoeffs(2), this.toProcsF2F.Valve_23.setFlowCoefficient(this.afFlowCoeffs(2)); end;
            end
        end
        
     end
    
end

