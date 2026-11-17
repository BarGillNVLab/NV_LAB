classdef KinesisStage < BaseObject
    % One Thorlabs K-Cube stepper axis (KST101 + ZFS25B) through Kinesis .NET.
    %
    % SAFETY: connecting never moves the stage - no homing, no enable, no
    % "go to" of any kind. The stage moves only when moveTo / moveBy / home
    % is called explicitly. The stages on this setup are not homed, so
    % positions are relative to wherever the controller counter stands.
    %
    %   z = KinesisStage('Z', '26001525');          % standalone
    %   stages = KinesisStage.getStages();          % all from setupInfo.json "kinesisStages"
    %   z = KinesisStage.get('Z');                  % one of those, by name
    %   z.position                                  % [mm]
    %   z.moveTo(3.0)                               % blocks until there (or timeout)
    %   z.moveBy(-0.01)
    %   z.moveTo(3.0, false)                        % returns at once; poll z.isMoving
    %   z.stop
    %   KinesisStage_gui                            % control window

    properties (Constant)
        KINESIS_DIR = 'C:\Program Files\Thorlabs\Kinesis\'
        POLL_MS = 100
        MOVE_TIMEOUT_MS = 60000
        POSITION_TOL_MM = 0.0003    % "arrived" = within 0.3 um of the target
        START_GRACE_S = 1           % after a command, a "not moving" status is not trusted for this long
    end

    properties (Access = private)
        lastTarget = NaN            % [mm] target of the last move command
        moveStarted                 % tic of the last move command
    end

    properties (SetAccess = private)
        serialNumber    % char
        minPosition     % [mm] soft limit
        maxPosition     % [mm] soft limit
        device          % Thorlabs.MotionControl.KCube.StepperMotorCLI.KCubeStepper
    end

    methods
        function obj = KinesisStage(name, serialNumber, minPosition, maxPosition)
            obj@BaseObject(name);
            obj.serialNumber = char(string(serialNumber));
            KinesisStage.loadAssemblies();
            import Thorlabs.MotionControl.DeviceManagerCLI.*
            import Thorlabs.MotionControl.KCube.StepperMotorCLI.*

            DeviceManagerCLI.BuildDeviceList();
            if ~any(strcmp(cell(DeviceManagerCLI.GetDeviceList().ToArray()), obj.serialNumber))
                error(['Kinesis stage %s (SN %s) not found. Is it powered and plugged in, ', ...
                    'and is the Thorlabs Kinesis app closed?'], name, obj.serialNumber);
            end
            obj.device = KCubeStepper.CreateKCubeStepper(obj.serialNumber);
            obj.device.Connect(obj.serialNumber);
            obj.device.WaitForSettingsInitialized(5000);
            obj.device.LoadMotorConfiguration(obj.serialNumber);   % mm units; does not move
            obj.device.StartPolling(obj.POLL_MS);

            lim = obj.device.AdvancedMotorLimits;
            travel = [System.Decimal.ToDouble(lim.LengthMinimum), System.Decimal.ToDouble(lim.LengthMaximum)];
            if nargin < 3 || isempty(minPosition); minPosition = travel(1); end
            if nargin < 4 || isempty(maxPosition); maxPosition = travel(2); end
            obj.minPosition = max(minPosition, travel(1));
            obj.maxPosition = min(maxPosition, travel(2));
        end

        function p = position(obj)
            p = System.Decimal.ToDouble(obj.device.Position);
        end

        function tf = isMoving(obj)
            % The controller's motion flag. Updated only every POLL_MS, so
            % right after a command it can still say "not moving" - use
            % isBusy() to know whether a move has finished.
            tf = obj.device.Status.IsInMotion;
        end

        function tf = isBusy(obj)
            % Whether the last commanded move is still under way. Done means
            % stopped AND at the target; during the first START_GRACE_S a
            % stopped status is not believed (it may predate the command).
            % A move that stopped short is "not busy" after the grace time -
            % callers check reached() for that.
            if obj.device.Status.IsInMotion; tf = true; return; end     % skip reading position while moving
            sinceCommand = Inf;
            if ~isnan(obj.lastTarget); sinceCommand = toc(obj.moveStarted); end
            tf = KinesisStage.busyRule(false, obj.position, obj.lastTarget, sinceCommand);
        end

        function tf = reached(obj, target)
            tf = abs(obj.position - target) <= obj.POSITION_TOL_MM;
        end

        function tf = isHomed(obj)
            tf = obj.device.Status.IsHomed;
        end

        function p = moveTo(obj, target, wait)
            % Absolute move [mm]. wait (default true) blocks until done.
            if nargin < 3; wait = true; end
            obj.checkTarget(target);
            obj.enableIfNeeded();
            if obj.isBusy()
                error('%s is still moving to %.4f mm - wait for it (or Stop) before a new move.', ...
                    obj.name, obj.lastTarget);
            end
            timeout = 0;
            if wait; timeout = obj.MOVE_TIMEOUT_MS; end
            obj.lastTarget = target;
            obj.moveStarted = tic;
            obj.device.MoveTo(System.Decimal(target), timeout);
            p = obj.position;
        end

        function p = moveBy(obj, delta, wait)
            if nargin < 3; wait = true; end
            p = obj.moveTo(obj.position + delta, wait);
        end

        function stop(obj)
            obj.device.StopImmediate();
            obj.lastTarget = NaN;   % no move under way any more
        end

        function home(obj)
            % Drives to the hardware limit switch to find true zero. Only
            % ever called on an explicit user request.
            obj.enableIfNeeded();
            obj.device.Home(obj.MOVE_TIMEOUT_MS);
        end

        function checkTarget(obj, target)
            if ~isscalar(target) || ~isfinite(target) || target < obj.minPosition || target > obj.maxPosition
                error('%s: target %g mm is outside %g..%g mm', obj.name, target, obj.minPosition, obj.maxPosition);
            end
        end

        function delete(obj)
            if ~isempty(obj.device)
                try
                    obj.device.StopPolling();
                    obj.device.Disconnect(true);    % does not move or de-energise the motor
                catch
                end
            end
        end
    end

    methods (Access = private)
        function enableIfNeeded(obj)
            if ~obj.device.IsEnabled
                obj.device.EnableDevice();
                pause(0.5);
            end
        end
    end

    methods (Static)
        function tf = busyRule(inMotion, position, target, sinceCommand)
            % The "is the last move still under way" rule, on plain numbers
            % so it can be tested without hardware (see isBusy).
            if inMotion; tf = true; return; end
            if isnan(target) || abs(position - target) <= KinesisStage.POSITION_TOL_MM; tf = false; return; end
            tf = sinceCommand < KinesisStage.START_GRACE_S;
        end

        function stages = getStages()
            % All stages listed in setupInfo.json "kinesisStages", created on
            % first call. Returns {} when the section is missing.
            stages = {};
            json = JsonInfoReader.getJson();
            if ~isfield(json, 'kinesisStages'); return; end
            list = json.kinesisStages;
            if isstruct(list); list = num2cell(list); end
            for i = 1:numel(list)
                s = list{i};
                stage = getObjByName(s.name);
                if isempty(stage) || ~isvalid(stage)
                    try
                        stage = KinesisStage(s.name, s.serialNumber, ...
                            KinesisStage.field(s, 'minPosition'), KinesisStage.field(s, 'maxPosition'));
                        addBaseObject(stage);
                    catch err
                        EventStation.anonymousWarning('Kinesis stage "%s" not connected: %s', s.name, err.message);
                        continue
                    end
                end
                stages{end+1} = stage; %#ok<AGROW>
            end
        end

        function stage = get(name)
            stage = getObjByName(name);
            if isempty(stage)
                KinesisStage.getStages();
                stage = getObjByName(name);
            end
            if isempty(stage); error('No Kinesis stage called "%s"', name); end
        end

        function loadAssemblies()
            persistent loaded
            if isempty(loaded)
                d = KinesisStage.KINESIS_DIR;
                NET.addAssembly([d 'Thorlabs.MotionControl.DeviceManagerCLI.dll']);
                NET.addAssembly([d 'Thorlabs.MotionControl.GenericMotorCLI.dll']);
                NET.addAssembly([d 'Thorlabs.MotionControl.KCube.StepperMotorCLI.dll']);
                loaded = true;
            end
        end
    end

    methods (Static, Access = private)
        function v = field(s, name)
            v = [];
            if isfield(s, name); v = s.(name); end
        end
    end
end
