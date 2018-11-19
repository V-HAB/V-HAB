classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1.0;
        fPipeDiameter = 0.0035;
        
        
        % Store volumes in m3
        afStoreVolumes = [ 50 50 50 ];
        
        % How many exmes to create?
        aiExmes = [ 1 2 1 ];
        
        % For air helper - create air for how much volume (multiple of
        % fVolume)
        arPressures = [ 2 1 3 ];
        
        
        % Branches between stores - Cvs for valves?
        afFlowCoeffs = [ 0.19 0.19 ];
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 100);
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            % Create three stores with three phases each. Also create
            % exmes, if several - append number!
            for iS = 1:length(this.afStoreVolumes)
                sS = sprintf('Tank_%i', iS);
                
                matter.store(this, sS, this.afStoreVolumes(iS));
                
                this.toStores.(sS).createPhase('air', this.arPressures(iS) * this.toStores.(sS).fVolume);
                
                if this.aiExmes(iS) == 1
                    matter.procs.exmes.gas(this.toStores.(sS).aoPhases(1), 'Port');
                else
                    for iE = 1:this.aiExmes(iS)
                        matter.procs.exmes.gas(this.toStores.(sS).aoPhases(1), sprintf('Port_%i', iE));
                    end
                end
            end
            
            
            % Create branches with pipes and valves
            iLen = length(this.afStoreVolumes) - 1;
            
            for iB = 1:iLen
                csFlowProcs = {
                    components.pipe(this, sprintf('Pipe_%i%i_1', iB, iB + 1), this.fPipeLength, this.fPipeDiameter).sName;
                	components.valve_pressure_drop(this, sprintf('Valve_%i%i',  iB, iB + 1), this.afFlowCoeffs(iB)).sName;
                	components.pipe(this, sprintf('Pipe_%i%i_2', iB, iB + 1), this.fPipeLength, this.fPipeDiameter).sName;
                };
                
                if iB == 1
                    csFlowProcs{end + 1} = components.checkvalve(this, sprintf('Checkvalve_%i%i',  iB, iB + 1)).sName;
                end
                
                if iB == 1
                    sString = 'Tank_%i.Port';
                else
                    sString = 'Tank_%i.Port_2';
                end
                sStoreLeft  = sprintf(sString, iB);
                if iB == iLen
                    sString = 'Tank_%i.Port';
                else
                    sString = 'Tank_%i.Port_1';
                end
                sStoreRight = sprintf(sString, iB + 1);
                
                %fprintf('%s -> ', sStoreLeft, csFlowProcs{:}, sStoreRight);
                %fprintf('\n');
                
                matter.branch(this, sStoreLeft, csFlowProcs, sStoreRight);
            end
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            for iB = 1:(length(this.afStoreVolumes) - 1)
                solver.matter.interval.branch(this.aoBranches(iB));
            end
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            
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

