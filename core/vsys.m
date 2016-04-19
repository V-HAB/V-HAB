classdef vsys < matter.container & thermal.container & electrical.container & systems.timed
    %VSYS Typical system in VHAB
    %   Derives from matter.container and the systems.timed class, i.e. 
    %   contains matter stores/processors and is executed with the parent 
    %   or from the timer with the according time step. Also derives from
    %   thermal.container to include thermal network and associated
    %   solvers. These are also coupled to the current time step.
    %   Also derives from electrical container to include electrical
    %   circuits and their associated solvers, also coupled to current time
    %   step.
    
    properties (SetAccess = protected, GetAccess = public)
        % Execute container .exec on this exec? Set to false if solver, atm
        %TODO throw out? need solver anyway, and if just a manual one?
        bExecuteContainer = false;
        
        bSealed;
    end
    
    methods
        function this = vsys(oParent, sName, fTimeStep)
            % Time step [] means with parent, -1 for every tick, 0 for
            % global time step.
            if nargin < 3, fTimeStep = false; end;
            
            % Leads to a double call of the sys constructor, that's ok
            % since this expected to happen and accordingly caught
            this@systems.timed(oParent, sName, 'oTimer', fTimeStep);
            this@matter.container(oParent, sName);
            this@thermal.container(oParent, sName);
            this@electrical.container(oParent, sName);
            
            % Setting the matter table
% %             this.oMT = this.oData.oMT;
            
%             if nargin >= 3
%                 this.setTimeStep(fTimeStep);
%             end
        end
        
        function createGeometricStructure(this)
            % Call in child elems
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                this.toChildren.(sChild).createGeometricStructure();
            end
        end

        function createSolverStructure(this)
            % Call in child elems
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                this.toChildren.(sChild).createSolverStructure();
            end
        end
        
        function seal(this)
            
            if this.bSealed
                this.throw('seal', 'Already sealed');
            end
            
            this.sealMatterStructure();
            this.sealElectricalStructure();
            this.sealThermalStructure();
            
            this.bSealed = true;
        end
        
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@systems.timed(this);
            
            if this.bExecuteContainer
                exec@matter.container(this, this.fLastTimeStep);
                exec@thermal.container(this, this.fLastTimeStep);
                exec@electrical.container(this, this.fLastTimeStep);
            end
        end
    end
    
end

