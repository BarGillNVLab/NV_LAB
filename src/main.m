function main()
Setup.init;
jsonStruct = JsonInfoReader.getJson();
iscamera = 0;
if strcmpi(jsonStruct.spcm.classname, 'camera')
    iscamera = 1;
end
GuiControllerImage(iscamera).start;
end