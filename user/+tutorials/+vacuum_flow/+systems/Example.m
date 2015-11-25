classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        oMan;
        
        fManualFlowRate = 0.005;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 25);
            
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            
            matter.store(this, 'Tank', 1);
            oPhase = this.toStores.Tank.createPhase('air', 0);
            matter.procs.exmes.gas(oPhase, 'ToVacuum');
            matter.procs.exmes.gas(oPhase, 'FromStore');
            
            matter.store(this, 'Vacuum', 100);
            oPhase = this.toStores.Vacuum.createPhase('air', 0);
            special.matter.const_press_exme(oPhase, 'In', 0);
            
            
            matter.store(this, 'Storage', 10000);
            oPhase = this.toStores.Storage.createPhase('air', 100);
            matter.procs.exmes.gas(oPhase, 'StoreOut');
            
            
            
            
            components.pipe(this, 'Pipe', 0.5, 0.005);
            
            
            
            
            matter.branch(this, 'Tank.ToVacuum', {'Pipe'}, 'Vacuum.In');
            matter.branch(this, 'Storage.StoreOut', {}, 'Tank.FromStore');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            oIt1 = solver.matter.iterative.branch(this.aoBranches(1));
            
            %oIt1.iDampFR = 5;
            
            
            this.oMan = solver.matter.manual.branch(this.aoBranches(2));
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            
            %TODO
            %   * obj attrs -> possible to set via config params
            %   * also trigger if fTime slightly BELOW the switch time,
            %     because that's what will happen if 'our' tick is grouped
            %     with another one, i.e. exec() will be called slightly
            %     earlier than planned.
            %      => 'round' up?
            %   * remember when FR was set, shut off 100s after THAT, not
            %     using mod()?
            %
            % Check - remove tick grouping?
            
            % Start at 3.6k ticks, set fr each 12 hours.
            iStart = 3600;
            iCycle = 3600 * 15;
            
            % How long should fr be active?
            iLength = 100;
            
            
            
            fTime = this.oTimer.fTime - iStart;
            
            if fTime < 0, return; end;
            
            fMod = mod(fTime, iCycle);
            
            bHourLow = (fMod < this.fTimeStep);
            
            %fprintf('[%i]@%5.5fs | %f @ %f\n', this.oTimer.iTick, this.oTimer.fTime, fMod, this.fTimeStep);
            
            if bHourLow && (this.oMan.fFlowRate == 0)
                fprintf('[%i] Set Flow Rate to %f at %fs\n', this.oTimer.iTick, this.fManualFlowRate, this.oTimer.fTime);
                this.oMan.setFlowRate(this.fManualFlowRate);
                
            elseif this.oMan.fFlowRate ~= 0
                if fMod > iLength
                    fprintf('[%i] Set Flow Rate to %f at %fs\n', this.oTimer.iTick, 0, this.oTimer.fTime);
                    this.oMan.setFlowRate(0);
                end
                
            end
            
            
            return;
            
            
            
%             if this.oTimer.fTime > 200 && this.oTimer.fTime < 211 && this.oMan.fFlowRate == 0
%                 this.oMan.setFlowRate(this.fManualFlowRate);
%                 
%             elseif this.oTimer.fTime > 300 && this.oTimer.fTime < 311 && this.oMan.fFlowRate ~= 0
%                 this.oMan.setFlowRate(0);
%                 
%                 
%             elseif this.oTimer.fTime > 50000 && this.oTimer.fTime < 50011 && this.oMan.fFlowRate == 0
%                 keyboard();
%                 this.oMan.setFlowRate(this.fManualFlowRate);
%                 
%             elseif this.oTimer.fTime > 50100 && this.oTimer.fTime < 50111 && this.oMan.fFlowRate ~= 0
%                 this.oMan.setFlowRate(0);
%                 
%             end
        end
        
     end
    
end

