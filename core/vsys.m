classdef vsys < matter.container & systems.timed
    %VSYS Typical system in VHAB
    %   Derives from matter.container and the systems.timed class, i.e. 
    %   contains matter stores/processors and is executed with the parent 
    %   or from the timer with the according time step.
    
    properties (SetAccess = protected, GetAccess = public)
        % Execute container .exec on this exec? Set to false if solver, atm
        bExecuteContainer = true;
    end
    
    methods
        function this = vsys(oParent, sName, fTimeStep)
            % Time step [] means with parent, -1 for every tick, 0 for
            % global time step.
            if nargin < 3, fTimeStep = []; end;
            
            % Leads to a double call of the sys constructor, that's ok
            % since this expected to happen and accordingly catched
            this@matter.container(oParent, sName);
            this@systems.timed(oParent, sName, 'oTimer', fTimeStep);
            
%             if nargin >= 3
%                 this.setTimeStep(fTimeStep);
%             end
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@systems.timed(this);
            
            if this.bExecuteContainer
                exec@matter.container(this, this.fLastTimeStep);
            end
        end
    end
    
end

