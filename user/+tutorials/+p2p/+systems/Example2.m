classdef Example2 < vsys
    %EXAMPLE2 Example simulation demonstrating P2P processors in V-HAB 2.0
    %   Creates two tanks, one with ~two bars of pressure, one completely
    %   empty tank. A filter is created. The tanks are connected to the filter with
    %   pipes of 50cm length and 5mm diameter.
    %   The filter only filters O2 (oxygen) up to a certain capacity.
    
    properties
    end
    
    methods
        function this = Example2(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            % Creating a store, volume 10m^3
            this.addStore(matter.store(this.oData.oMT, 'Atmos', 10));
            
            % Creating normal air (standard atmosphere) for 20m^3. Will
            % have 2 bar of pressure because the store is actually smaller.
            oAir = this.toStores.Atmos.createPhase('air', 20);
            
            % Adding a default extract/merge processors to the phase
            matter.procs.exmes.gas(oAir, 'Out');
            
            % Creating a second store 
            this.addStore(matter.store(this.oData.oMT, 'Atmos2', 10));
            
            % Better usage of air helper than above - provide the correct
            % volume, then empty values for temperature and humidity (so
            % the defaults are used) and then the parameter for the
            % pressure.
            oAir = this.toStores.Atmos2.createPhase('air', 10, [], [], 0);
            
            % Adding a default extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'In');
            
            % Create the filter. See the according files, just an example
            % for an implementation - copy to your own directory and change
            % as needed.
            this.addStore(tutorials.p2p.components.Filter(this.oData.oMT, 'Filter', 0.1));
            
            % Adding pipes to connect the components
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_1', 0.5, 0.01));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_2', 0.5, 0.01));
            
            % Creating the flowpath between the components
            this.createBranch('Atmos.Out',  { 'Pipe_1' }, 'Filter.In');
            this.createBranch('Filter.Out', { 'Pipe_2' }, 'Atmos2.In');
            
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

