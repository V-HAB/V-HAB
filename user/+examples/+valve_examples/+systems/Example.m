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
                
                this.toStores.(sS).createPhase('air', this.toStores.(sS).fVolume, 293, 0.5, 10^5 * this.arPressures(iS));
                
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
                    components.matter.pipe(this, sprintf('Pipe_%i%i_1', iB, iB + 1), this.fPipeLength, this.fPipeDiameter).sName;
                	components.matter.valve(this, sprintf('Valve_%i%i',  iB, iB + 1)).sName;
                	components.matter.pipe(this, sprintf('Pipe_%i%i_2', iB, iB + 1), this.fPipeLength, this.fPipeDiameter).sName;
                };
                
                if iB == 1
                    csFlowProcs{end + 1} = components.matter.checkvalve(this, sprintf('Checkvalve_%i%i',  iB, iB + 1)).sName;
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
                    this.toProcsF2F.Valve_12.setOpen(true);
                    
                elseif this.toProcsF2F.Valve_12.bOpen && ~this.toProcsF2F.Valve_23.bOpen
                    this.toProcsF2F.Valve_23.setOpen(true);
                    
                elseif ~this.toProcsF2F.Valve_12.bOpen && this.toProcsF2F.Valve_23.bOpen
                    this.toProcsF2F.Valve_23.setOpen(false);
                    
                else % both open
                    this.toProcsF2F.Valve_12.setOpen(false);
                    
                end
                
            
            % Emulate Cvs
            elseif this.oTimer.fTime > (1800 - this.fTimeStep) && this.oTimer.fTime < 5400
                if this.fTimeStep ~= 5
                    this.setTimeStep(5);
                end
                
            % Something to reset?
            else
                if this.fTimeStep ~= 100
                    this.setTimeStep(100);
                end
                
                
                if ~this.toProcsF2F.Valve_12.bOpen, this.toProcsF2F.Valve_12.setOpen(true); end
                if ~this.toProcsF2F.Valve_23.bOpen, this.toProcsF2F.Valve_23.setOpen(true); end
                
            end
        end
        
     end
    
end

