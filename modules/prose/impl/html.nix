{ lib, ... }:
{
  _module.args.html =
    let
      h = tag: arg1: {
        inherit tag;
        childNodes =
          if lib.isString arg1 then
            [ arg1 ]
          else if lib.isAttrs arg1 then
            lib.id
          else if lib.isList arg1 then
            arg1
          else
            throw "type error";
      };
      render =
        nodes:
        lib.pipe nodes [
          (map (
            node:
            if lib.isString node then
              node
            else
              (lib.concatLines [
                "<${node.tag}>"
                (render node.childNodes)
                "</${node.tag}>"
              ])
          ))
          lib.concatLines
        ];
    in
    {
      inherit h render;
      tags = lib.genAttrs [ "p" ] h;
    };
}
