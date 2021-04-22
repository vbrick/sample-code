/*
 * Reference
 * https://docs.microsoft.com/en-us/dotnet/standard/serialization/system-text-json-converters-how-to?pivots=dotnet-core-3-1#sample-basic-converter
 * */
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace VBrick.ConsoleApp.Processing
{
    /// <summary>
    /// Converts between a DateTimeOffset and a specific date string format.
    /// </summary>
    public class DateTimeOffsetJsonConverter : JsonConverter<DateTimeOffset>
    {
        private const string DATE_FORMAT = "MM/dd/yyyy HH:mm:ss";

        public override DateTimeOffset Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options) =>
                DateTimeOffset.ParseExact(reader.GetString(),
                    DATE_FORMAT, CultureInfo.InvariantCulture);

        public override void Write(
            Utf8JsonWriter writer,
            DateTimeOffset dateTimeValue,
            JsonSerializerOptions options) =>
                writer.WriteStringValue(dateTimeValue.ToString(
                    DATE_FORMAT, CultureInfo.InvariantCulture));
    }
}
