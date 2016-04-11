classdef node < base
    %NODE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        fVoltage;
        
        aoTerminals = electrical.terminal.empty();
        
        toTerminals = struct();
        
        iTerminals;
        
        oCircuit;
        
        sName;
        
        bSealed;
    end
    
    methods
        
        function this = node(oCircuit, sName)
            this.oCircuit = oCircuit;
            this.sName = sName;
            
            this.oCircuit.addNode(this);
            
        end
        
        function addTerminal(this, oTerminal)
            this.aoTerminals(end+1) = oTerminal;
            this.toTerminals.(oTerminal.sName) = oTerminal;
            
        end
        
        function seal(this)
            this.iTerminals = length(this.aoTerminals);
            this.bSealed = true;
        end
        
        function oTerminal = getTerminal(this, sTerminalName)
            
            try 
                oTerminal = this.toTerminals.(sTerminalName);
            catch
                if ~isfield(this.toTerminals, sTerminalName)
                    this.throw('getTerminal','There is no terminal ''%s'' on node %s.', sTerminalName, this.sName);
                end
            end
        end
        
        function createTerminals(this, iNumberOfTerminals)
            for iI = 1:iNumberOfTerminals
                electrical.terminal(this);
            end
        end
        
        function setVoltage(this, fVoltage)
            this.fVoltage = fVoltage;
        end
    end
    
end

