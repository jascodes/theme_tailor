import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';
import 'package:theme_tailor_annotation/theme_tailor_annotation.dart';

import '../../theme_tailor.dart';
import '../util/message.dart';
import '../util/string_format.dart';

class ThemeTailorGenerator extends GeneratorForAnnotation<Tailor> {
  @override
  String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement || element is Enum) {
      throw InvalidGenerationSourceError(Message.unsupportedAnnotationTarget(element), element: element);
    }

    final className = element.displayName.formatClassName();
    final themeNames = annotation.read('themes').listValue.map((e) => e.toStringValue()!);

    final strBuffer = StringBuffer()
      ..writeln(commented('DEBUG PRINT:'))
      ..writeln(commented('class name: $className'))
      ..writeln(commented('themes: $themeNames'));

    /// DEBUG PLAYGROUND
    final parsedLibResult = element.session!.getParsedLibraryByElement(element.library) as ParsedLibraryResult;
    final elDeclarationResult = parsedLibResult.getElementDeclaration(element)!;

    final tailorAnnotation = elDeclarationResult.node.childEntities.first as Annotation;
    final tailorProps =
        (tailorAnnotation.arguments!.arguments[0] as ListLiteral).elements.whereType<MethodInvocation>();

    final themeExtensionFields = <ThemeExtensionField>[];

    annotation.read('props').listValue.forEachIndexed((i, propValues) {
      final tailorProp = tailorProps.elementAt(i);

      final name = propValues.getField('name')!.toStringValue()!;

      /// Encoder expression (as it is typed in the annotation)
      final encoder = tailorProp.argumentList.arguments
          .whereType<NamedExpression>()
          .firstWhereOrNull((element) => element.name.label.name == 'encoder')
          ?.expression;
      final encoderType = propValues.getField('encoder')?.type;

      /// Values expression (as it is typed in the annotation)
      final values = (tailorProp.argumentList.arguments.elementAt(1) as ListLiteral).elements;
      final valuesTypes = propValues.getField('values')!.toListValue()!.map((e) => e.type);

      strBuffer
        ..writeln(commented('name: $name'))
        ..writeln(commented('encoder: ${encoder ?? '-'} | type: $encoderType'))
        ..writeln(commented('values: $values | type: $valuesTypes'));

      themeExtensionFields.add(ThemeExtensionField(name, values, valuesTypes, encoder, encoderType));

      // This won't work if it is a SimpleIdentifierImpl
      // final tailorPropEncoderType = (tailorPropEncoder?.expression as MethodInvocation?)?.methodName;

      // ..writeln(commented('encoderType: $tailorPropEncoderType'));
    });

    final config = ThemeExtensionConfig.fromData(className, themeNames, themeExtensionFields);
    final template = ThemeExtensionClassTemplate(config);
    return '${strBuffer.toString()}\n\n${template.generate()}';
  }
}

String commented(String val) => '/// $val';
