classdef Example < vsys
    %EXAMPLE Example simulation demonstrating the use of f2f processors
    %   The model contains three tanks filled with gas at different
    %   pressures. Between each tank are two pipes with a valve in the
    %   middle, connecting the tanks in series. Use the arrays in the
    %   editable properties section to vary the volumes and pressures.
    %   In the exec() method of this class the valves are cycled several
    %   times during a simulation run to show the effects on the flow rates
    %   throughout the system.
    
    % Fixed properties
    properties (SetAccess = protected, GetAccess = public)
        % Standard pipe length for this tutorial
        fPipeLength   = 1.0;

        % Standard pipe diameter for this tutorial
        fPipeDiameter = 0.0035;
        
        % How many exmes to create?
        aiExmes = [ 1 2 1 ];
    end
    
    % Editable properties
    properties
        % Store volumes in m3
        afStoreVolumes = [ 50 50 50 ];
        
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
            
            iNumberOfTanks = length(this.afStoreVolumes);

            % Create three stores with one phase each. Also create
            % exmes on each phase, if there are several - append number!
            for iStore = 1:iNumberOfTanks
                sStoreName = sprintf('Tank_%i', iStore);
                
                matter.store(this, sStoreName, this.afStoreVolumes(iStore));
                
                this.toStores.(sStoreName).createPhase('air', this.toStores.(sStoreName).fVolume, 293, 0.5, 10^5 * this.arPressures(iStore));
                
                if this.aiExmes(iStore) == 1
                    matter.procs.exmes.gas(this.toStores.(sStoreName).aoPhases(1), 'Port');
                else
                    for iExMe = 1:this.aiExmes(iStore)
                        matter.procs.exmes.gas(this.toStores.(sStoreName).aoPhases(1), sprintf('Port_%i', iExMe));
                    end
                end
            end
            
            % Create branches with pipes and valves
            iNumberOfBranches = iNumberOfTanks - 1;
            
            for iBranch = 1:iNumberOfBranches
                csFlowProcs = {
                    components.matter.pipe(this,  sprintf('Pipe_%i%i_1', iBranch, iBranch + 1), this.fPipeLength, this.fPipeDiameter).sName;
                	components.matter.valve(this, sprintf('Valve_%i%i',  iBranch, iBranch + 1)).sName;
                	components.matter.pipe(this,  sprintf('Pipe_%i%i_2', iBranch, iBranch + 1), this.fPipeLength, this.fPipeDiameter).sName;
                };
                
                if iBranch == 1
                    csFlowProcs{4} = components.matter.checkvalve(this, sprintf('Checkvalve_%i%i',  iBranch, iBranch + 1)).sName;
                end
                
                if iBranch == 1
                    sString = 'Tank_%i.Port';
                else
                    sString = 'Tank_%i.Port_2';
                end

                sStoreLeft  = sprintf(sString, iBranch);

                if iBranch == iNumberOfBranches
                    sString = 'Tank_%i.Port';
                else
                    sString = 'Tank_%i.Port_1';
                end

                sStoreRight = sprintf(sString, iBranch + 1);
                
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
            
            exec@vsys(this);
            
            % Open/Close valves every 50 seconds (setTimeStep(50)) between
            % 7200 and 9000 seconds into the simulation.
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

