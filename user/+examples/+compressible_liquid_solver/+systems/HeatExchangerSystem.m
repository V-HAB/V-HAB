classdef HeatExchangerSystem < vsys
    %EXAMPLE Example simulation for V-HAB 2.0
    %   This class creates blubb
    
    properties
        aoLiquidBranch;
        oHX;
    end
    
    methods
        function this = HeatExchangerSystem(oParent, sName)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName, 60);
            
            % Creating a store
            this.addStore(matter.store(this.oData.oMT, 'Tank_1', 0.2, 0));
            this.addStore(matter.store(this.oData.oMT, 'Tank_2', 0.2, 0));
            this.addStore(matter.store(this.oData.oMT, 'Tank_3', 0.1, 0));
            this.addStore(matter.store(this.oData.oMT, 'Tank_4', 0.1, 0));
            
            % Adding phases
            oWaterPhase1 = this.toStores.Tank_1.createPhase('water', 0.1, 313, 50*10^5);
            oWaterPhase2 = this.toStores.Tank_2.createPhase('water', 0.1, 313, 50*10^5);
            oWaterPhase3 = this.toStores.Tank_3.createPhase('water', 0.1, 293, 50*10^5);
            oWaterPhase4 = this.toStores.Tank_4.createPhase('water', 0.1, 293, 50*10^5);
            oAirPhase1   = this.toStores.Tank_1.createPhase('air', 0.1, 313, 0, 50*10^5);
            oAirPhase2   = this.toStores.Tank_2.createPhase('air', 0.1, 313, 0, 50*10^5);
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.liquid(oWaterPhase1, 'Port_1' );
            matter.procs.exmes.liquid(oWaterPhase1, 'Port_2');
            matter.procs.exmes.liquid(oWaterPhase2, 'Port_1');
            matter.procs.exmes.liquid(oWaterPhase2, 'Port_2');
            matter.procs.exmes.liquid(oWaterPhase3, 'Port_1');
            matter.procs.exmes.liquid(oWaterPhase3, 'Port_2');
            matter.procs.exmes.liquid(oWaterPhase4, 'Port_1');
            matter.procs.exmes.liquid(oWaterPhase4, 'Port_2');
            
            % Adding pipes to connect the components
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_1', 0.5, 0.1, 0.2*10^-3));
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_2', 0.5, 0.1, 0.2*10^-3));
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_3', 0.5, 0.1, 0.2*10^-3));
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_4', 0.5, 0.1, 0.2*10^-3));
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_5', 0.5, 0.1, 0.2*10^-3));
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_6', 0.5, 0.1, 0.2*10^-3));
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_7', 0.5, 0.1, 0.2*10^-3));
            this.addProcF2F(components.matter.pipe(this.oData.oMT, 'Pipe_8', 0.5, 0.1, 0.2*10^-3));
            
            % Adding pumps
            this.addProcF2F(tutorials.compressible_liquid_solver.components.fan(this.oData.oMT, 'Fan_1', 2*10^5));
            this.addProcF2F(tutorials.compressible_liquid_solver.components.fan(this.oData.oMT, 'Fan_2', 2*10^5));
            %this.addProcF2F(components.matter.fan(this.oData.oMT, 'Fan_1', 2*10^5));
            %this.addProcF2F(components.matter.fan(this.oData.oMT, 'Fan_2', 2*10^5));
            
            %conductivity of HX material
            Conductivity = 15;
            
            %HX Type and Geometry
            sHX_type = 'counter annular passage';
            Geometry = [0.2, 0.3, (0.19/2), 0.5];
            
            % HX Params: oParent, sName, mHX, sHX_type, fHX_TC
            % adding the heat exchanger
            this.oHX = components.matter.HX(this, 'HeatExchanger', Geometry, sHX_type, Conductivity);
            
            %adding the processors from the heat exchanger to the system
            this.addProcF2F(this.oHX.oF2F_1);
            this.addProcF2F(this.oHX.oF2F_2);
            
            this.createBranch('Tank_1.Port_1', {'Pipe_1','HeatExchanger_1', 'Pipe_2'}, 'Tank_2.Port_1');
            this.createBranch('Tank_3.Port_1', {'Pipe_3','HeatExchanger_2', 'Pipe_4'}, 'Tank_4.Port_1');
            this.createBranch('Tank_2.Port_2', {'Pipe_5', 'Fan_1', 'Pipe_6'}, 'Tank_1.Port_2');
            this.createBranch('Tank_4.Port_2', {'Pipe_7', 'Fan_2', 'Pipe_8'}, 'Tank_3.Port_2');

            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

